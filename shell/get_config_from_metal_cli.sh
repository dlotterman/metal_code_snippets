#!/bin/bash

HOME=$(getent passwd "$USER" | cut -d: -f6)

if [ -f "$HOME""/.config/equinix/metal.yaml" ]; then
	echo "found metal-cli, using for shell config"
	METAL_AUTH_TOKEN=$(cat ~/.config/equinix/metal.yaml  | grep token | awk '{print$NF}')
	METAL_ORG_ID=$(cat ~/.config/equinix/metal.yaml  | grep organization-id | awk '{print$NF}')
	export METAL_AUTH_TOKEN
	export METAL_ORG_ID
else
	echo "metal-cli config not found (~/.config/equinix/metal.yaml), exiting"
fi
