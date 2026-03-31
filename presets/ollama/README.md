# presets/ollama

Ollama model presets. Each `.env` file sets the model name and runtime parameters (`OLLAMA_NUM_CTX`, `OLLAMA_NUM_THREAD`).

## Usage

```bash
rig ollama list                            # show all presets, ✓ marks default
rig ollama start nomic-embed-text          # start with a preset (pulls model if not cached)
rig ollama start deepseek-r1-14b --gpu    # GPU mode
rig presets set ollama phi3-mini          # change default preset
rig presets show phi3-mini                # inspect preset config
```

## Presets

**Embeddings**

| Preset | Model | Use |
|---|---|---|
| `nomic-embed-text` | nomic-embed-text | Primary RAG embeddings |
| `mxbai-embed-large` | mxbai-embed-large | Higher-quality embeddings |
| `all-minilm` | all-minilm | Ultra-fast minimal embeddings |

**Vision**

| Preset | Model | Use |
|---|---|---|
| `llava-13b` | llava:13b | Multimodal image description |
| `moondream` | moondream | Lightweight vision |
| `llava-phi3` | llava-phi3 | Vision + reasoning |

**Language (CPU-optimised)**

| Preset | Model | Use |
|---|---|---|
| `phi3-mini` | phi3:mini | Fast utility, summarization |
| `phi3-medium` | phi3:medium | Stronger reasoning |
| `gemma2-2b` | gemma2:2b | Compact, low VRAM |
| `gemma2-9b` | gemma2:9b | Better quality |
| `mistral-7b` | mistral:7b | Strong instruction following |
| `mistral-nemo` | mistral-nemo | Extended context |
| `qwen2.5-7b` | qwen2.5:7b | Multilingual |
| `qwen2.5-14b` | qwen2.5:14b | Multilingual, higher quality |
| `llama3.2-1b` | llama3.2:1b | Ultra-compact |
| `llama3.2-3b` | llama3.2:3b | Compact, capable |

**Code**

| Preset | Model | Use |
|---|---|---|
| `codellama-7b` | codellama:7b | Code generation |
| `codegemma-7b` | codegemma:7b | Code + instruction |
| `deepseek-coder-6.7b` | deepseek-coder:6.7b | Strong code completion |

**Reasoning**

| Preset | Model | Use |
|---|---|---|
| `deepseek-r1-7b` | deepseek-r1:7b | Chain-of-thought, CPU |
| `deepseek-r1-14b` | deepseek-r1:14b | Stronger, GPU recommended |
