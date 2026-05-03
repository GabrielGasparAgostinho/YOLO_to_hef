# 🚀 YOLOv11 to Hailo HEF Converter
### *Streamlined Pipeline for Hailo Model Zoo Integration*

This script provides an automated **end-to-end pipeline** to convert models trained in **YOLOv11** (PyTorch `.pt` format) to the compiled format for Hailo neural accelerators (`.hef`).

The process automatically handles the model export with the correct flags and orchestrates the compilation using the **Hailo Model Zoo** encapsulated in a **Docker container**, ensuring a clean and isolated environment.

---

## ✨ Features

*   **🎯 Optimized Export:** Converts the `.pt` model to `.onnx` ensuring compatibility with the Hailo compiler (`opset=11`, `simplify=True`, `imgsz=640`).
*   **🐳 Docker Isolation:** Executes Parsing, Optimization, and Compilation processes (Hailo Model Zoo) inside a dedicated container, avoiding dependency conflicts.
*   **🧠 Automatic Parameter Adjustment:** Injects memory allocation parameters (`allocator_param(timeout=0)`) into Hailo's `.alls` scripts to prevent compilation failures on dense models.
*   **📁 Log and Artifact Management:** Automatically organizes generated files (`.onnx`, `.har`, logs, and `.hef`) into timestamp-based directories.

---

## 🛠️ Prerequisites & Setup

The script divides the workload into two stages: **Local Execution** (ONNX export) and **Docker Execution** (Hailo compilation).

### 1. Local Environment (ONNX Export)
You need the `ultralytics` package installed on your host system:

```bash
# Recommended: use a virtual environment (venv or conda)
pip install ultralytics onnx onnxsim
```

### 2. Docker & Hailo Setup
The script relies on the official **Hailo AI Software Suite** Docker image.

*   **Docker:** Ensure Docker is installed and running (`sudo apt install docker.io`).
*   **Hailo Image:** Download the **Hailo AI Software Suite (v2025-10)** from the Hailo Developer Zone.
*   **Load Image:** If you have a `.tar` file:
    ```bash
    docker load -i hailo8_ai_sw_suite_2025-10.tar
    ```

> [!IMPORTANT]
> If your Docker image tag differs from `hailo8_ai_sw_suite_2025-10:1`, update the `DOCKER_IMAGE` variable on **line 34** of `convert_yolo_hailomz.sh`.

---

## 💻 How to Use

### Permissions
```bash
chmod +x convert_yolo_hailomz.sh
```

### Execution Syntax
```bash
./convert_yolo_hailomz.sh <PT_PATH> <CALIBRATION_DATASET_PATH> <NUM_CLASSES> [HAILOMZ_ARCHITECTURE]
```

#### Parameters:
*   **`<PT_PATH>`**: Path to your trained model weights (`.pt`).
*   **`<CALIBRATION_DATASET_PATH>`**: Folder containing images (JPG/PNG) for quantization. *Tip: Use ~1000 images from your training set.*
*   **`<NUM_CLASSES>`**: Number of classes your model detects.
*   **`[HAILOMZ_ARCHITECTURE]`**: *(Optional)* Base architecture (e.g., `yolov11n`). Default is `yolov11n`.

### Practical Example:
```bash
# Converting a YOLOv11n model for 1 class (e.g., manometers)
./convert_yolo_hailomz.sh pt/script.pt datasets/calib_images/ 1 yolov11n
```

---

## 📂 Directory Structure

The script automatically organizes outputs in your project directory:

```text
your_project/
├── convert_yolo_hailomz.sh
├── pt/
│   └── script.pt        <-- Original model
├── datasets/
│   └── calib_images/                    <-- Calibration images
├── hef/
│   └── script.hef       <-- ✅ FINAL COMPILED MODEL
└── logs_hef/
    └── log_script_hef(2026-05-03_14-30-00)/
        ├── export.log                   <-- ONNX conversion log
        ├── script.onnx  <-- Intermediate ONNX
        ├── hailomz.log                  <-- Detailed Hailo compiler log
        └── script.har   <-- Hailo Archive (for Profiler)
```

---

## ⚙️ Technical Details & Best Practices

*   **📐 Fixed Resolution (640x640):** The script forces `imgsz=640` for static input tensors. Edit the export line in the script if you need a different resolution.
*   **🎯 Hardware Target:** Default is **Hailo-8L** (`--hw-arch hailo8l`). To change this (e.g., to `hailo8`, `hailo15h`), modify the `--hw-arch` parameter in the `hailomz compile` command within the script.
*   **⏱️ Compilation Time:** Quantization and optimization are intensive. Expect **30 minutes to a few hours** depending on your CPU.
*   **🔍 Troubleshooting:** If generation fails, check `logs_hef/.../hailomz.log`. Common issues: incorrect mount paths or unsupported ONNX nodes.
*   **🔄 History & Overwriting:** The final `.hef` in `hef/` is overwritten on each run, but a full history of logs and intermediate files is preserved in timestamped folders within `logs_hef/`.