// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@solmate/utils/FixedPointMathLib.sol";
import "@solmate/utils/SafeTransferLib.sol";
import "@solmate/tokens/ERC20.sol";
import "@solmate/mixins/ERC4626.sol";

import "./Bank.sol";
import "./UniswapV3Helper.sol";

error Account_Not_The_Owner(address owner);
error Account_Asset_Not_Supported(address asset);
error Account_Insufficient_Balance(
    address asset,
    uint256 balance,
    uint256 amount
);
error Account_Vault_Not_Supported(address vault);
error Account_Default_SubAccount_Can_Be_Linked();

contract Account {
    using SafeTransferLib for ERC20;
    Bank public bank;
    UniswapV3Helper public uniswapV3Helper;
    struct VaultInfo {
        ERC4626 vault;
        uint256 share;
    }

    mapping(uint256 => mapping(address => uint256))
        public subAccountIdToAssetToBalance;
    mapping(uint256 => VaultInfo) public subAccountIdToVault;

    event Deposit(address asset, uint256 amount, uint256 subAccountId);
    event Withdraw(address asset, uint256 amount, uint256 subAccountId);
    event Transfer(
        address asset,
        uint256 amount,
        uint256 subAccountIdFrom,
        uint256 subAccountIdTo
    );
    event Swap(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event SubAccountLinkedToVault(uint256 subAccountId, address vault);

    constructor(address _bank, address _uniswapV3Helper) {
        bank = Bank(_bank);
        uniswapV3Helper = UniswapV3Helper(_uniswapV3Helper);
    }

    modifier onlyOwner() {
        if (bank.ownerOf(address(this)) != msg.sender) {
            revert Account_Not_The_Owner(msg.sender);
        }
        _;
    }
    modifier isAssetSupported(address _asset) {
        if (!bank.isAssetSupported(_asset)) {
            revert Account_Asset_Not_Supported(_asset);
        }
        _;
    }

    modifier enoughBalance(
        address _asset,
        uint256 _amount,
        uint256 _subAccountId
    ) {
        checkBalance(_asset, _amount, _subAccountId);
        _;
    }

    function deposit(
        address _asset,
        uint256 _amount
    ) external isAssetSupported(_asset) {
        ERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        subAccountIdToAssetToBalance[0][_asset] += _amount;
        emit Deposit(_asset, _amount, 0);
    }

    function deposit(
        address _asset,
        uint256 _amount,
        uint256 _subAccountId
    ) external isAssetSupported(_asset) {
        ERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);

        VaultInfo memory vaultInfo_ = subAccountIdToVault[_subAccountId];
        if (
            address(vaultInfo_.vault) != address(0) &&
            address(vaultInfo_.vault.asset()) == _asset
        ) {
            updateVaultDeposit(vaultInfo_, _amount);
        }
        unchecked {
            subAccountIdToAssetToBalance[_subAccountId][_asset] += _amount;
        }
        emit Deposit(_asset, _amount, 0);
    }

    function withdraw(
        address _asset,
        uint256 _amount
    )
        external
        onlyOwner
        isAssetSupported(_asset)
        enoughBalance(_asset, _amount, 0)
    {
        unchecked {
            subAccountIdToAssetToBalance[0][_asset] -= _amount;
        }
        ERC20(_asset).safeTransfer(msg.sender, _amount);
        emit Withdraw(_asset, _amount, 0);
    }

    function updateVaultDeposit(
        VaultInfo memory _vaultInfo,
        uint256 _amount
    ) internal {
        ERC20 asset_ = _vaultInfo.vault.asset();
        asset_.safeApprove(_vaultInfo.vault, _amount);
        _vaultInfo.share += _vaultInfo.vault.deposit(_amount, address(this));
    }

    function updateVaultWithdraw(
        VaultInfo memory _vaultInfo,
        address _asset,
        uint256 _amount,
        uint256 _subAccountId
    ) internal {
        uint256 newBalance = _vaultInfo.vault.previewRedeem(_vaultInfo.share);
        if (newBalance < _amount) {
            revert Account_Insufficient_Balance(
                _asset,
                subAccountIdToAssetToBalance[_subAccountId][_asset],
                _amount
            );
        }
        _vaultInfo.share -= _vaultInfo.vault.withdraw(
            _amount,
            address(this),
            address(this)
        );
        subAccountIdToAssetToBalance[_subAccountId][address(_asset)] =
            newBalance -
            _amount;
    }

    function checkBalance(
        address _asset,
        uint256 _amount,
        uint256 _subAccountId
    ) internal view {
        if (subAccountIdToAssetToBalance[_subAccountId][_asset] < _amount) {
            revert Account_Insufficient_Balance(
                _asset,
                subAccountIdToAssetToBalance[_subAccountId][_asset],
                _amount
            );
        }
    }

    function getBalance(
        address _asset,
        uint256 _subAccountId
    ) external view returns (uint256) {
        return subAccountIdToAssetToBalance[_subAccountId][_asset];
    }
}
