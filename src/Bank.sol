// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@solmate/tokens/ERC20.sol";

import "./VaultCeFi.sol";

error Bank_Account_Already_Created(address user);
error Bank_Asset_Already_Added(address asset);
error Bank_Vault_Already_Added(address vault);
error Bank_Asset_Not_Supported(address asset);

contract Bank is ERC721, Ownable {
    mapping(address => bool) private supportedVaults;
    mapping(address => bool) private supportedAssets;
    address public uniswapV3Helper;

    event AccountCreated(address indexed account);
    event VaultCreated(address indexed vault);
    event AssetAdded(address indexed asset);

    constructor(
        address _admin,
        address _uniswapHelper
    ) ERC721("Mini-Bank", "Bank") {
        transferOwnership(_admin);
        uniswapV3Helper = _uniswapHelper;
    }

    modifier vaultNotAdded(address _vault) {
        if (!supportedVaults[_vault]) {
            revert Bank_Vault_Already_Added(_vault);
        }
        _;
    }

    modifier assetAdded(address _asset) {
        if (!supportedAssets[_asset]) {
            revert Bank_Asset_Already_Added(_asset);
        }
        _;
    }

    function createAccount() external returns (address) {
        address account_ = address(new Account(address(this), uniswapV3Helper));
        _safeMint(msg.sender, account_);
        emit AccountCreated(account_);
        return account_;
    }

    function addAssest(address _asset) external onlyOwner {
        if (supportedAssets[_asset]) {
            revert Bank_Asset_Already_Added();
        }
        supportedAssets[_asset] = true;
        emit AssetAdded(_asset);
    }

    function createVaultCeFi(
        address _asset,
        address _admin
    ) external onlyOwner assetAdded(_asset) returns (address) {
        address vault = address(new VaultCeFi(ERC20(_asset), _admin));
        supportedVaults[vault] = true;
        emit VaultCreated(vault);
        return vault;
    }

    function createVaultDeFi(
        address _vault
    ) external onlyOwner assetAdded(_asset) {
        address asset_ = address(ERC4626(_vault).asset());
        if (!supportedAssets[asset_]) {
            revert Bank_Asset_Not_Supported(asset_);
        }
        supportedVaults[_vault] = true;
        emit VaultCreated(_vault);
    }

    function getUserAccount(
        address _accountAddress
    ) external view returns (address) {
        return ownerOf(_accountAddress);
    }

    function isVaultSupported(address _vault) external view returns (bool) {
        return supportedVaults[_vault];
    }

    function isAssetSupported(address _asset) external view returns (bool) {
        return supportedAssets[_asset];
    }
}
