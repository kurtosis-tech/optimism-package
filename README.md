# Optimism Package [WIP]

# Pre Setup

Note this package depends on some images existing locally

```py
OPS_BEDROCK_L1_IMAGE = "ops-bedrock-l1:latest"
OPS_BEDROCK_L2_IMAGE = "ops-bedrock-l2:latest"
OP_NODE_IMAGE = "ops-bedrock-op-node:latest"
OP_PROPOSER_IMAGE = "ops-bedrock-op-proposer:latest"
OP_BATCHER_IMAGE = "ops-bedrock-op-batcher:latest"
OP_STATEVIZ_IMAGE = "ops-bedrock-stateviz:latest"
```

To have these images ready you should run `docker compose build --progress plan` from inside `optimism/ops-bedrock`

# Run Instructions

1. kurtosis run github.com/kurtosis-tech/optimism-package --enclave optimism

# Test Instructions

1. kurtosis run github.com/kurtosis-tech/optimism-package --enclave optimism
2. make devnet-test

Kurtosis spins up different services on different ports inside the enclave; have to make some changes like the [following](https://github.com/ethereum-optimism/optimism/pull/7729/files) to launch tests; note use `kurtosis enclave inspect optimism` to get the 
right ports; I can automate this with a few scripts as well.

My `make devnet-test` are getting stuck at [this point](https://github.com/ethereum-optimism/optimism/blob/develop/packages/sdk/tasks/deposit-erc20.ts#L334-L335); but I see this happening for `make devnet-up && make devnet-test` too; so wondering if it
stale files.