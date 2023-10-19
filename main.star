# skylark is a language that is a subset of python used by bazel
# it's good for writing configurations with a little more expressiveness than something like toml
OPS_BEDROCK_L1_IMAGE = "ops-bedrock-l1:latest"
OPS_BEDROCK_L2_IMAGE = "ops-bedrock-l2:latest"
OP_NODE_IMAGE = "ops-bedrock-op-node:latest"
OP_PROPOSER_IMAGE = "ops-bedrock-op-proposer:latest"
OP_BATCHER_IMAGE = "ops-bedrock-op-batcher:latest"
OP_STATEVIZ_IMAGE = "ops-bedrock-stateviz:latest"
ARTIFACT_SERVER_IMAGE = "nginx:1.25-alpine"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546

# this is adapted from the optimism monorepo
# https://github.com/ethereum-optimism/optimism/blob/develop/bedrock-devnet/devnet/__init__.py
def run(plan):
    uploaded_files = upload_config_and_genesis_files(plan)

    # his could be just stock geth 
    # https://github.com/ethereum-optimism/optimism/blob/develop/ops-bedrock/Dockerfile.l1
    l1 = launch_l1(plan, uploaded_files)
    # this one could be op geth https://github.com/ethereum-optimism/optimism/blob/develop/ops-bedrock/Dockerfile.l2
    l2 = launch_l2(plan, uploaded_files)
    op_node = launch_op_node(plan, uploaded_files, l1, l2)
    op_proposer = launch_proposer(plan, uploaded_files, l1, op_node)
    op_batcher = launch_batcher(plan, uploaded_files, l1, l2, op_node)
    artifact_server = launch_artifact_server(plan, uploaded_files)
    # this needs the op node to work; otherwise the file will be empty
    # my read is that the op-node wrtites to snapshot.log
    # this guy reads it; is my understanding
    # we can just launch this as a background process in the op-node image
    stateviz = launch_stateviz(plan)

    return struct(
        l1=l1,
        l2=l2,
        op_node=op_node,
        op_proposer=op_proposer,
        artifact_server=artifact_server,
        stateviz=stateviz,
    )


def launch_batcher(plan, uploaded_files, l1, l2, op_node):
    # plan.add_service is similar to a service in a docker-compose file
    return plan.add_service(
        name="op-batcher",
        config=ServiceConfig(
            image=OP_BATCHER_IMAGE,
            ports={
                # I believe PortSpec is a kurtosis thing
                "rpc": PortSpec(RPC_PORT_NUM),
                "metrics": PortSpec(7300),
                "pprof": PortSpec(6060),
            },
            env_vars={
                "OP_BATCHER_L1_ETH_RPC": "http://{0}:{1}".format(l1.name, RPC_PORT_NUM),
                "OP_BATCHER_L2_ETH_RPC": "http://{0}:{1}".format(l2.name, RPC_PORT_NUM),
                "OP_BATCHER_ROLLUP_RPC": "http://{0}:{1}".format(
                    op_node.name, RPC_PORT_NUM
                ),
                "OP_BATCHER_MAX_CHANNEL_DURATION": "1",
                "OP_BATCHER_SUB_SAFETY_MARGIN": "4",  # SWS is 15, ChannelTimeout is 40"
                "OP_BATCHER_POLL_INTERVAL": "1s",
                "OP_BATCHER_NUM_CONFIRMATIONS": "1",
                "OP_BATCHER_MNEMONIC": "test test test test test test test test test test test junk",
                "OP_BATCHER_SEQUENCER_HD_PATH": "m/44'/60'/0'/0/2",
                "OP_BATCHER_PPROF_ENABLED": "true",
                "OP_BATCHER_METRICS_ENABLED": "true",
                "OP_BATCHER_RPC_ENABLE_ADMIN": "true",
            },
        ),
    )


def launch_proposer(plan, uploaded_files, l1, op_node):
    return plan.add_service(
        name="op-proposer",
        config=ServiceConfig(
            image=OP_PROPOSER_IMAGE,
            ports={
                "pprof": PortSpec(6060),
                "rpc": PortSpec(RPC_PORT_NUM),
                "metrics": PortSpec(7300),
            },
            env_vars={
                "OP_PROPOSER_L1_ETH_RPC": "http://{0}:{1}".format(
                    l1.name, RPC_PORT_NUM
                ),
                "OP_PROPOSER_ROLLUP_RPC": "http://{0}:{1}".format(
                    op_node.name, RPC_PORT_NUM
                ),
                "OP_PROPOSER_POLL_INTERVAL": "1s",
                "OP_PROPOSER_NUM_CONFIRMATIONS": "1",
                "OP_PROPOSER_MNEMONIC": "test test test test test test test test test test test junk",
                "OP_PROPOSER_L2_OUTPUT_HD_PATH": "m/44'/60'/0'/0/1",
                # TODO - make this address not hardcoded, currently this is the L2OutputOracle in the generated addresses.json
                "OP_PROPOSER_L2OO_ADDRESS": "0x8203dEBE6cD849358473715fD46FE9b1aE44C44D",
                "OP_PROPOSER_PPROF_ENABLED": "true",
                "OP_PROPOSER_METRICS_ENABLED": "true",
                "OP_PROPOSER_ALLOW_NON_FINALIZED": "true",
                "OP_PROPOSER_RPC_ENABLE_ADMIN": "true",
            },
        ),
    )


def launch_op_node(plan, uploaded_files, l1, l2):
    return plan.add_service(
        name="op-node",
        config=ServiceConfig(
            image=OP_NODE_IMAGE,
            cmd=[
                "op-node",
                "--l1=ws://{0}:{1}".format(l1.name, WS_PORT_NUM),
                "--l2=http://{0}:8551".format(l2.name),
                "--l2.jwt-secret=/config/test-jwt-secret.txt",
                "--sequencer.enabled",
                "--sequencer.l1-confs=0",
                "--verifier.l1-confs=0",
                "--p2p.sequencer.key=8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
                "--rollup.config=/rollup/rollup.json",
                "--rpc.addr=0.0.0.0",
                "--rpc.port={0}".format(RPC_PORT_NUM),
                "--p2p.listen.ip=0.0.0.0",
                "--p2p.listen.tcp=9003",
                "--p2p.listen.udp=9003",
                "--p2p.scoring.peers=light",
                "--p2p.ban.peers=true",
                # slight diversion as we don't have op_log volume
                "--snapshotlog.file=/tmp/snapshot.log",
                "--p2p.priv.path=/config/p2p-node-key.txt",
                "--metrics.enabled",
                "--metrics.addr=0.0.0.0",
                "--metrics.port=7300",
                "--pprof.enabled",
                "--rpc.enable-admin",
            ],
            ports={
                "rpc": PortSpec(RPC_PORT_NUM),
                "metrics": PortSpec(7300),
                "pprof": PortSpec(6060),
                "p2p-tcp": PortSpec(9003),
                "p2p-udp": PortSpec(9003, transport_protocol="UDP"),
            },
            files={"/config/": uploaded_files.config, "/rollup": uploaded_files.rollup},
        ),
    )


def launch_stateviz(plan):
    return plan.add_service(
        name="stateviz",
        config=ServiceConfig(
            image=OP_STATEVIZ_IMAGE,
            ports={
                "http": PortSpec(
                    8080, transport_protocol="TCP", application_protocol="http"
                ),
            },
            cmd=[
                "stateviz",
                "-addr",
                "0.0.0.0:8080",
                "-snapshot",
                "/tmp/snapshot.log",
                "-refresh=10s",
            ],
        ),
    )


def launch_l2(plan, uploaded_files):
    return plan.add_service(
        name="l2",
        config=ServiceConfig(
            image=OPS_BEDROCK_L2_IMAGE,
            ports={
                "rpc": PortSpec(number=RPC_PORT_NUM),
                "metrics": PortSpec(number=6060),
            },
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l2.json"},
            entrypoint=[
                "/bin/sh",
                "/entrypoint.sh",
                "--authrpc.jwtsecret=/config/test-jwt-secret.txt",
            ],
            files={
                "/config/": uploaded_files.config,
                "/genesis/": uploaded_files.l2_genesis,
            },
        ),
    )


def launch_l1(plan, uploaded_files):
    # To highlight - waits are automatic here
    return plan.add_service(
        name="l1",
        config=ServiceConfig(
            image=OPS_BEDROCK_L1_IMAGE,
            ports={
                "rpc": PortSpec(number=RPC_PORT_NUM),
                "ws": PortSpec(number=WS_PORT_NUM),
                "metrics": PortSpec(number=6060),
            },
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l1.json"},
            files={
                "/config/": uploaded_files.config,
                "/genesis/": uploaded_files.l1_genesis,
            },
        ),
    )


def launch_artifact_server(plan, uploaded_files):
    return plan.add_service(
        name="artifacts-server",
        config=ServiceConfig(
            image=ARTIFACT_SERVER_IMAGE,
            ports={
                "http": PortSpec(
                    80, transport_protocol="TCP", application_protocol="http"
                )
            },
            files={"/usr/share/nginx/html/": uploaded_files.all_generated},
        ),
    )


# Will question: when does this happen compared to everything else? Do we generate the files before we generate the final starlark config or is it evaluated after?
def upload_config_and_genesis_files(plan):
    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l1_genesis = plan.upload_files(
        src="./static_files/generated_files/genesis-l1.json", name="l1-genesis"
    )

    #  This file is checked in to the repository; so is static
    config = plan.upload_files(src="./static_files/config", name="jwt-secret")

    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l2_genesis = plan.upload_files(
        src="./static_files/generated_files/genesis-l2.json", name="l2-genesis"
    )

    rollup = plan.upload_files(
        src="./static_files/generated_files/rollup.json", name="rollup"
    )

    all_generated = plan.upload_files(
        "./static_files/generated_files", name="generated-files"
    )

    return struct(
        l1_genesis=l1_genesis,
        l2_genesis=l2_genesis,
        config=config,
        rollup=rollup,
        all_generated=all_generated,
    )
