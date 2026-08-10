import time
import argparse
import numpy as np
import torch
import torch.nn as nn
from medmnist import BloodMNIST

# -------------------------------------------------------------
# 1. Standard FP32 Architecture (Needed to load state_dict)
# -------------------------------------------------------------
class MicroCNN(nn.Module):
    def __init__(self, num_classes=8, use_bias=True): 
        super(MicroCNN, self).__init__()
        self.conv1 = nn.Conv2d(3, 8, kernel_size=3, bias=use_bias) 
        self.relu1 = nn.ReLU()
        self.pool1 = nn.MaxPool2d(2, 2)
        
        self.conv2 = nn.Conv2d(8, 16, kernel_size=3, bias=use_bias)
        self.relu2 = nn.ReLU()
        self.pool2 = nn.MaxPool2d(2, 2)
        
        self.fc1 = nn.Linear(16 * 5 * 5, 32, bias=use_bias)
        self.relu3 = nn.ReLU()
        self.fc2 = nn.Linear(32, num_classes, bias=use_bias)

    def forward(self, x):
        x = self.pool1(self.relu1(self.conv1(x)))
        x = self.pool2(self.relu2(self.conv2(x)))
        x = torch.flatten(x, 1)
        x = self.relu3(self.fc1(x))
        x = self.fc2(x)
        return x

# -------------------------------------------------------------
# 2. Quantized Hardware Simulation Functions
# -------------------------------------------------------------
def quant_conv2d(x_quant, w_quant, b_quant):
    w_f, w_c, w_h, w_w = w_quant.shape
    x_h, x_w, x_c =  x_quant.shape
    out_h = x_h - w_h + 1
    out_w = x_w - w_w + 1

    x32 = x_quant.astype(np.int32)
    w32 = w_quant.astype(np.int32)
    b32 = b_quant.astype(np.int32)
    w32_hwc = np.transpose(w32, (0,2,3,1))

    conv_out = np.zeros((out_h, out_w, w_f), dtype=np.int32)

    for f_idx in range(w_f):
        for h_idx in range(out_h):
            for w_idx in range(out_w):
                window = x32[h_idx:h_idx+w_h, w_idx:w_idx+w_w, :]
                mac = b32[f_idx] 
                mac += np.sum(window * w32_hwc[f_idx, :, :, :]).astype(np.int32) 
                conv_out[h_idx, w_idx, f_idx] = mac 
    return conv_out

def quant_ReLU(x_quant):
    return np.maximum(x_quant, 0, dtype=np.int32)

def quant_maxpool(x_quant, stride):
    x_h, x_w, x_c = x_quant.shape
    out_h = x_h // stride
    out_w = x_w // stride
    maxpool_out = np.zeros((out_h, out_w, x_c), dtype=np.uint8)

    for c in range(x_c):
        for i in range(out_h):
            for j in range(out_w):
                max_val = np.max(x_quant[i*stride:(i+1)*stride, j*stride:(j+1)*stride, c]).astype(np.uint8)
                maxpool_out[i, j, c] = max_val
    return maxpool_out

def quant_linear(x_quant, w_quant, b_quant):
    w_out, w_in = w_quant.shape
    x32 = x_quant.astype(np.int32)
    w32 = w_quant.astype(np.int32)
    b32 = b_quant.astype(np.int32)
    linear_out = np.zeros((w_out,), dtype=np.int32)

    for out_idx in range(w_out):
        mac = b32[out_idx]
        mac += np.sum(x32 * w32[out_idx, :]).astype(np.int32)
        linear_out[out_idx] = mac
    return linear_out

# -------------------------------------------------------------
# 3. Model Loader & Execution
# -------------------------------------------------------------
def load_and_quantize_model(pth_path):
    print(f"[*] Loading FP32 model from '{pth_path}'...")
    model = MicroCNN(use_bias=True)
    model.load_state_dict(torch.load(pth_path, map_location='cpu', weights_only=True))
    model.eval()

    # Derived from mathematical cascaded scales
    weight_scale = 64
    bias_scales = {
        'conv1': 16320,
        'conv2': 4080,
        'fc1': 2040,
        'fc2': 510
    }

    quant_params = {}
    print("[*] Quantizing parameters to INT8/INT32...")
    for name, module in model.named_modules():
        if isinstance(module, (nn.Conv2d, nn.Linear)):
            quant_params[name] = {}
            w_float = module.weight.detach().numpy()
            w_int = np.round(w_float * weight_scale)
            quant_params[name]['weight'] = np.clip(w_int, -128, 127).astype(np.int8)
            
            if module.bias is not None:
                b_float = module.bias.detach().numpy()
                b_int32 = np.round(b_float * bias_scales[name])
                quant_params[name]['bias'] = b_int32.astype(np.int32)
            else:
                quant_params[name]['bias'] = None
                
    return quant_params

def run_benchmark(index, split):
    print(f"[*] Loading BloodMNIST '{split}' dataset...")
    dataset = BloodMNIST(split=split, download=False, as_rgb=True)
    
    in_data = dataset.imgs[index]
    true_label = dataset.labels[index][0]
    
    quant_params = load_and_quantize_model('micro_cnn_blood.pth')
    
    print(f"\n[*] Starting Golden Model Inference for Index {index}...")
    
    # === START BENCHMARK TIMER ===
    start_time = time.time()
    
    # Layer 1
    conv1 = quant_conv2d(in_data, quant_params['conv1']['weight'], quant_params['conv1']['bias'])
    conv1_relu = quant_ReLU(conv1)
    conv1_shifted = np.clip((conv1_relu // 512), 0, 255).astype(np.uint8)
    maxpool1 = quant_maxpool(conv1_shifted, 2)

    # Layer 2
    conv2 = quant_conv2d(maxpool1, quant_params['conv2']['weight'], quant_params['conv2']['bias'])
    conv2_relu = quant_ReLU(conv2)
    conv2_shifted = np.clip((conv2_relu // 256), 0, 255).astype(np.uint8)
    maxpool2 = quant_maxpool(conv2_shifted, 2)

    # Flatten
    maxpool2_chw = np.transpose(maxpool2, (2, 0, 1))
    conv_flat = maxpool2_chw.flatten()

    # Layer 3 (FC1)
    fc1 = quant_linear(conv_flat, quant_params['fc1']['weight'], quant_params['fc1']['bias'])
    fc1_relu = quant_ReLU(fc1)
    fc1_shifted = np.clip((fc1_relu // 512), 0, 255).astype(np.uint8)

    # Layer 4 (FC2)
    fc2 = quant_linear(fc1_shifted, quant_params['fc2']['weight'], quant_params['fc2']['bias'])
    result_label = np.argmax(fc2)
    
    # === STOP BENCHMARK TIMER ===
    end_time = time.time()
    
    print("\n========================================")
    print(f"   [TRUE LABEL]             : {true_label}")
    print(f"   [GOLDEN MODEL PREDICTION]: {result_label}")
    print(f"   [MATCH?]                 : {'YES' if result_label == true_label else 'NO'}")
    print(f"   [TIMING] CPU Latency     : {(end_time - start_time) * 1000:.2f} ms")
    print("========================================\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Python Golden Model Benchmark for MicroCNN")
    parser.add_argument("index", type=int, help="Index of the BloodMNIST image to test")
    parser.add_argument("--split", type=str, default="test", choices=["train", "val", "test"], help="Dataset split to use (default: test)")
    
    args = parser.parse_args()
    
    try:
        run_benchmark(args.index, args.split)
    except Exception as e:
        print(f"Fatal Error: {e}")