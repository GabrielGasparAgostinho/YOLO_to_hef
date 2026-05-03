#!/usr/bin/env bash
# =============================================================================
# Script Unificado de Conversão YOLOv11 -> Hailo HEF via Hailo Model Zoo
# =============================================================================
# Este script automatiza o processo end-to-end:
# 1. Exporta o modelo .pt para .onnx na resolução 640x640.
# 2. Roda o hailomz dentro do Docker para Parser, Optimize e Compile.
# =============================================================================

if [ "$#" -lt 3 ]; then
    echo "Uso: $0 <CAMINHO_DO_PT> <CAMINHO_DATASET_CALIBRACAO> <NUM_CLASSES> [ARQUITETURA_HAILOMZ]"
    echo "Exemplo: $0 pt/manometerDetector(last).pt datasets/dataset_detector/images/train 1 yolov11n"
    echo ""
    echo "  <CAMINHO_DO_PT>            : Caminho para o arquivo de pesos PyTorch (.pt)"
    echo "  <CAMINHO_DATASET_CALIBRACAO> : Caminho da pasta contendo imagens JPG/PNG para calibrar"
    echo "  <NUM_CLASSES>              : Número de classes do seu modelo"
    echo "  [ARQUITETURA_HAILOMZ]      : (Opcional) Arquitetura base no Hailo Model Zoo. Padrão: yolov11n"
    exit 1
fi

PT_PATH="$1"
CALIB_PATH="$2"
CLASSES="$3"
ARCH="${4:-yolov11n}"

if [ ! -f "$PT_PATH" ]; then
    echo "Erro: Arquivo .pt não encontrado em '$PT_PATH'"
    exit 1
fi

if [ ! -d "$CALIB_PATH" ]; then
    echo "Erro: Pasta do dataset de calibração não encontrada em '$CALIB_PATH'"
    exit 1
fi

WORKDIR="$(pwd)"
NET_NAME="$(basename "$PT_PATH" .pt)"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
LOG_DIR="$WORKDIR/logs_hef/log_${NET_NAME}_hef(${TIMESTAMP})"
DOCKER_IMAGE="hailo8_ai_sw_suite_2025-10:1"

echo "======================================================"
echo " Iniciando Conversão Unificada"
echo " Modelo: $NET_NAME"
echo " Arquitetura Base: $ARCH"
echo " Número de Classes: $CLASSES"
echo "======================================================"

mkdir -p "$LOG_DIR"
mkdir -p "$WORKDIR/hef"

# 1. Exportando para ONNX
echo "  [1/2] Exportando .pt -> .onnx (opset=11, simplify=True, imgsz=640)..."
yolo export model="$WORKDIR/$PT_PATH" format=onnx simplify=True opset=11 imgsz=640 > "$LOG_DIR/export.log" 2>&1

# Move o ONNX gerado para a pasta de log (usamos -f para sobrescrever se já existir)
mv -f "$WORKDIR/$(dirname "$PT_PATH")/${NET_NAME}.onnx" "$LOG_DIR/${NET_NAME}.onnx"

# 2. Rodando o Hailomz (Parser + Optimize + Compiler)
echo "  [2/2] Compilando ONNX para HEF com Hailo Model Zoo (hailomz)..."
echo "        (Atenção: Este processo pode levar de 30 minutos a mais de 2 horas)"

tmp_out="$(mktemp -d)"
chmod 777 "$tmp_out"

# Comando Docker (Monta a raiz para o dataset, monta a pasta de logs para o ONNX, e mapeia a saida temporária)
docker run --rm -v "$WORKDIR:/workdir:ro" -v "$LOG_DIR:/log_in:ro" -v "$tmp_out:/tmp_out" -w /tmp_out "$DOCKER_IMAGE" bash -c "
    echo 'allocator_param(timeout=0)' >> /local/workspace/hailo_model_zoo/hailo_model_zoo/cfg/alls/generic/${ARCH}.alls || true
    hailomz compile $ARCH --hw-arch hailo8l --ckpt '/log_in/${NET_NAME}.onnx' --calib-path '/workdir/${CALIB_PATH}' --classes $CLASSES --performance
" > "$LOG_DIR/hailomz.log" 2>&1

if [ -f "$tmp_out/${ARCH}.hef" ]; then
    cp "$tmp_out/${ARCH}.hef" "$WORKDIR/hef/${NET_NAME}.hef"
    echo "  ✅  Conversão concluída com SUCESSO! Salvo em hef/${NET_NAME}.hef"
    
    # Salvar também o arquivo .har (Hailo Archive) na pasta de log
    if [ -f "$tmp_out/${ARCH}.har" ]; then
        cp "$tmp_out/${ARCH}.har" "$LOG_DIR/${NET_NAME}.har"
        echo "  📦  Arquivo .har (Hailo Archive) salvo em: $LOG_DIR/${NET_NAME}.har"
    fi
else
    echo "  ❌  Falha na compilação. O arquivo .hef não foi gerado."
    echo "      Verifique os logs completos em: $LOG_DIR/hailomz.log"
fi

# Limpeza
rm -rf "$tmp_out"
echo "======================================================"
