This repository contains Solidity smart contracts for creating campaigns and distributing rewards. The system is designed to be deployed on multiple chains, enabling users to create campaigns, manage cross-chain rewards, and claim them using Merkle proofs.

## Overview

This project consists of two main contracts:
1. **CampaignCreator**: Allows users to create campaigns with specific parameters such as reward tokens, amounts, and durations.
2. **Distributor**: Manages the distribution of rewards to users based on Merkle proofs.

The system is designed to be chain-agnostic, enabling deployment and interaction across multiple blockchain networks.

---

## Deployment

### DeployCampaignCreator

Deploys the `CampaignCreator` contract.

#### Usage
```bash
forge script script/DeployCampaignCreator.sol --rpc-url <RPC_URL> --broadcast --verify -vvvv
```

### DeployDistributor

Deploys the Distributor contract on multiple chains.

#### Usage
```bash
forge script script/DeployDistributor.sol --rpc-url <RPC_URL> --broadcast --verify -vvvv
```

## Scripts

### CreateCampaignScript

Creates a new campaign using the CampaignCreator contract.

#### Usage
```bash
forge script script/CreateCampaignScript.sol --rpc-url <RPC_URL> --broadcast -vvvv
```
### UpdateRootScript

Updates the Merkle root in the Distributor contract.

#### Usage
```bash
forge script script/UpdateRootScript.sol --rpc-url <RPC_URL> --broadcast -vvvv
```
### ClaimScript

Allows users to claim rewards from the Distributor contract.

#### Usage
```bash
forge script script/ClaimScript.sol --rpc-url <RPC_URL> --broadcast -vvvv
```
