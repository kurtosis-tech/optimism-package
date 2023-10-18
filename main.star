OPS_BEDROCK_L1_IMAGE = "ops-bedrock-l1:latest"


def run(plan):
    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l1_genesis = plan.upload_files(
        src="./static_files/genesis-l1.json", name="l1-genesis"
    )

    #  This file is checked in to the repository; so is static
    jwt_secret_artifact = plan.upload_files(
        src="./static_files/test-jwt-secret.txt", name="jwt-secret"
    )

    plan.add_service(
        name="l1",
        config=ServiceConfig(
            image=OPS_BEDROCK_L1_IMAGE,
            ports={
                "grpc": PortSpec(number=8545, transport_protocol="TCP"),
                "ws": PortSpec(number=8546, transport_protocol="TCP"),
                "metrics": PortSpec(number=6060, transport_protocol="TCP"),
            },
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l1.json"},
            files={
                "/config/": jwt_secret_artifact,
                "/genesis/": l1_genesis,
            },
        ),
    )
