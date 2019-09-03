pragma solidity 0.5.10;

import "../lib/math/SafeMath.sol";
import "./BrokerExtension.sol";
import "../BrokerUtils.sol";

interface KyberNetworkProxy {
    function kyberNetworkContract() external view returns (address);
    function trade(address src, uint256 srcAmount, address dest, address payable destAddress, uint256 maxDestAmount, uint256 minConversionRate, address walletId) external payable returns (uint256);
}

contract KyberSwapDapp is BrokerExtension {
    using SafeMath for uint256;

    KyberNetworkProxy public kyberNetworkProxy;
    address private constant ETHER_ADDR = address(0);
    address private constant KYBER_ETHER_ADDR = address(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

    constructor(address _kyberNetworkProxyAddress) public {
        kyberNetworkProxy = KyberNetworkProxy(_kyberNetworkProxyAddress);
    }

    function setKyberNetworkProxy(
        address _kyberNetworkProxyAddress
    )
        external
        onlyOwner
    {
        kyberNetworkProxy = KyberNetworkProxy(_kyberNetworkProxyAddress);
    }

    function tokenReceiver(
        address[] calldata /* _assetIds */,
        uint256[] calldata /* _dataValues */,
        address[] calldata /* _addresses */
    )
        external
        view
        returns(address)
    {
        return address(this);
    }

    function trade(
        address[] calldata _assetIds,
        uint256[] calldata _dataValues,
        address[] calldata _addresses,
        address payable _recipient
    )
        external
        payable
    {
        uint256 ethValue = 0;

        if (_assetIds[0] != ETHER_ADDR) {
            BrokerUtils.transferTokensIn(msg.sender, _assetIds[0], _dataValues[0], _dataValues[0]);
            address kyberNetworkContract = kyberNetworkProxy.kyberNetworkContract();
            BrokerUtils.approveTokenTransfer(
                _assetIds[0],
                kyberNetworkContract,
                _dataValues[0]
            );
        } else {
            ethValue = _dataValues[0];
        }

        address srcAssetId = _assetIds[0] == ETHER_ADDR ? KYBER_ETHER_ADDR : _assetIds[0];
        address dstAssetId = _assetIds[1] == ETHER_ADDR ? KYBER_ETHER_ADDR : _assetIds[1];

        // _dataValues[2] bits(24..32): fee sharing walletAddressIndex
        uint256 walletAddressIndex = (_dataValues[2] & ~(~uint256(0) << 32)) >> 24;

        kyberNetworkProxy.trade.value(ethValue)(
            srcAssetId,
            _dataValues[0], // srcAmount
            dstAssetId, // dest
            _recipient, // destAddress
            ~uint256(0), // maxDestAmount
            uint256(0), // minConversionRate
            _addresses[walletAddressIndex] // walletId
        );
    }
}
