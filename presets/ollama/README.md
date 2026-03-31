# presets/ollama

Ollama model presets. Each `.env` file sets the default model and runtime params.

## Usage

```bash
rig ollama start nomic-embed-text          # uses embedding.env params
rig ollama start phi3-mini --gpu           # GPU mode
rig presets show embedding                 # inspect preset
```

## Presets

| File | Model | Use |
|---|---|---|
| `embedding.env` | nomic-embed-text | RAG embeddings — fast, CPU-only |
| `util.env` | phi3-mini | Summarization, classification, routing |

## All available Ollama models

Pull any of these with `rig ollama start <model>` (Ollama auto-pulls if not cached):

**Embeddings**
- `nomic-embed-text` — primary RAG embeddings
- `mxbai-embed-large` — higher-quality embeddings
- `all-minilm` — ultra-fast minimal embeddings

**Vision**
- `llava:13b` — multimodal image description
- `moondream` — lightweight vision
- `llava-phi3` — vision + reasoning

**Language (CPU-optimised)**
- `phi3-mini`, `phi3:medium` — fast utility
- `gemma2:2b`, `gemma2:9b` — Google Gemma
- `mistral:7b`, `mistral-nemo` — strong instruction following
- `qwen2.5:7b`, `qwen2.5:14b` — multilingual
- `llama3.2:1b`, `llama3.2:3b` — Meta Llama compact

**Code**
- `codellama:7b`, `codegemma:7b`, `deepseek-coder:6.7b`

**Reasoning**
- `deepseek-r1:7b` — chain-of-thought (CPU)
- `deepseek-r1:14b` — stronger (GPU recommended)
