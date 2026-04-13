"""
matrix.py — Run matrix builder
--------------------------------
Plan §5: takes the enriched services dict from the bash orchestrator and
the filtered test list from catalog.py, then emits the full cross-product
of tests × services × models as a flat list of RunSpec objects.

The bash orchestrator is responsible for resolving which services are live
and which models are loaded; this module only expands that into individual
run units.

Public API
  build(services_info, tests) -> list[RunSpec]

  services_info format (from bash --services-json flag):
    {
      "vllm":   {"models": ["Vendor/Model-Name"], "runtime": "GPU"},
      "ollama": {"models": ["gemma4:31b", "llama3:8b"], "runtime": "CPU"},
      ...
    }
"""
from dataclasses import dataclass, field


@dataclass
class RunSpec:
    """One unit of benchmark work: a single test on one model of one service."""
    # --- test ---
    test_name:  str
    test_type:  str        # "completion" or "vision"
    max_tokens: int
    prompt:     str
    image_path: str

    # --- target ---
    service: str
    model:   str
    runtime: str           # "GPU", "CPU", or "-"

    # --- optional ---
    tags: list = field(default_factory=list)

    def to_test_dict(self) -> dict:
        """Return the test fields as a plain dict (for payload.build)."""
        return {
            "name":       self.test_name,
            "type":       self.test_type,
            "max_tokens": self.max_tokens,
            "prompt":     self.prompt,
            "image_path": self.image_path,
            "tags":       self.tags,
        }


def build(services_info: dict, tests: list[dict]) -> list[RunSpec]:
    """Build the full run matrix: each test × each service × each model."""
    specs = []
    for test in tests:
        for service, info in services_info.items():
            models  = info.get("models", [])
            runtime = str(info.get("runtime", "-"))
            for model in models:
                specs.append(RunSpec(
                    test_name=test["name"],
                    test_type=test["type"],
                    max_tokens=test["max_tokens"],
                    prompt=test["prompt"],
                    image_path=test["image_path"],
                    tags=test.get("tags", []),
                    service=service,
                    model=model,
                    runtime=runtime,
                ))
    return specs
