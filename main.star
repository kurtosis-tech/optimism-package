OPS_BEDROCK_L1_IMAGE = "ops-bedrock-l1:latest"
OPS_BEDROCK_L2_IMAGE = "ops-bedrock-l2:latest"


def run(plan):
    config_files = upload_config_files(plan)

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
                "/config/": config_files.jwt_secret_artifact,
                "/genesis/": config_files.l1_genesis,
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
                "/config/": config_files.jwt_secret_artifact,
                "/genesis/": config_files.l2_genesis,
            },
        ),
    )


def upload_config_files(plan):
    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l1_genesis = plan.upload_files(
        src="./static_files/genesis-l1.json", name="l1-genesis"
    )

    #  This file is checked in to the repository; so is static
    jwt_secret_artifact = plan.upload_files(
        src="./static_files/test-jwt-secret.txt", name="jwt-secret"
    )

    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l2_genesis = plan.upload_files(
        src="./static_files/genesis-l2.json", name="l2-genesis"
    )

    return struct(
        l1_genesis=l1_genesis,
        l2_genesis=l2_genesis,
        jwt_secret_artifact=jwt_secret_artifact,
    )
