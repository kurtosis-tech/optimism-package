OPS_BEDROCK_L1_IMAGE = "ops-bedrock-l1:latest"
OPS_BEDROCK_L2_IMAGE = "ops-bedrock-l2:latest"
OP_NODE_IMAGE = "ops-bedrock-op-node:latest"


def run(plan):
    uploaded_files = upload_config_and_genesis_files(plan)

    # To highlight - waits are automatic here
    plan.add_service(
        name="l1",
        config=ServiceConfig(
            image=OPS_BEDROCK_L1_IMAGE,
            ports={
                "grpc": PortSpec(number=8545),
                "ws": PortSpec(number=8546),
                "metrics": PortSpec(number=6060),
            },
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l1.json"},
            files={
                "/config/": uploaded_files.config,
                "/genesis/": uploaded_files.l1_genesis,
            },
        ),
    )

    plan.add_service(
        name="l2",
        config=ServiceConfig(
            image=OPS_BEDROCK_L2_IMAGE,
            ports={"grpc": PortSpec(number=8545), "metrics": PortSpec(number=6060)},
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l2.json"},
            files={
                "/config/": uploaded_files.config,
                "/genesis/": uploaded_files.l2_genesis,
            },
        ),
    )

    plan.add_service(
        name="op-node",
        config=ServiceConfig(
            image=OP_NODE_IMAGE,
            cmd=[
                "op-node",
                "--l1=ws://l1:8546",
                "--l2=http://l2:8551",
                "--l2.jwt-secret=/config/test-jwt-secret.txt",
                "--sequencer.enabled",
                "--sequencer.l1-confs=0",
                "--verifier.l1-confs=0",
                "--p2p.sequencer.key=8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
                "--rollup.config=/rollup/rollup.json",
                "--rpc.addr=0.0.0.0",
                "--rpc.port=8545",
                "--p2p.listen.ip=0.0.0.0",
                "--p2p.listen.tcp=9003",
                "--p2p.listen.udp=9003",
                "--p2p.scoring.peers=light",
                "--p2p.ban.peers=true",
                "--snapshotlog.file=/tmp/snapshot.log",
                "--p2p.priv.path=/config/p2p-node-key.txt",
                "--metrics.enabled",
                "--metrics.addr=0.0.0.0",
                "--metrics.port=7300",
                "--pprof.enabled",
                "--rpc.enable-admin",
            ],
            ports={
                "grpc": PortSpec(8545),
                "metrics": PortSpec(7300),
                "metrics-alt": PortSpec(6060),
                "p2p-tcp": PortSpec(9003),
                "p2p-udp": PortSpec(9003, transport_protocol="UDP"),
            },
            files={"/config/": uploaded_files.config, "/rollup": uploaded_files.rollup},
        ),
    )


def upload_config_and_genesis_files(plan):
    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l1_genesis = plan.upload_files(
        src="./static_files/genesis/genesis-l1.json", name="l1-genesis"
    )

    #  This file is checked in to the repository; so is static
    config = plan.upload_files(src="./static_files/config", name="jwt-secret")

    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l2_genesis = plan.upload_files(
        src="./static_files/genesis/genesis-l2.json", name="l2-genesis"
    )

    rollup = plan.upload_files(src="./static_files/rollup.json", name="rollup")

    return struct(
        l1_genesis=l1_genesis,
        l2_genesis=l2_genesis,
        config=config,
        rollup=rollup,
    )
