// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {

    // Implement core logic here
    address public tokenA_;
    address public tokenB_;
    uint256 public reserveA_;
    uint256 public reserveB_;

    constructor(address _tokenA, address _tokenB) ERC20("LP TOKEN", "LP") {
        require(isContract(_tokenA),"SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(isContract(_tokenB),"SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA!=_tokenB,"SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        if(uint256(uint160(_tokenA))< uint256(uint160(_tokenB))){
            tokenA_ = _tokenA;
            tokenB_ = _tokenB;
        }
        else{
            tokenA_ = _tokenB;
            tokenB_ = _tokenA;
        }
    }

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) 
        external virtual override returns (uint256 amountOut) {
        require(tokenIn==tokenA_ || tokenIn==tokenB_ , "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut==tokenA_ || tokenOut==tokenB_ , "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn!=tokenOut , "SimpleSwap: IDENTICAL_ADDRESS");

        //get amountOut
        uint256 reserveIn = tokenIn == tokenA_ ? reserveA_ : reserveB_;
        uint256 reserveOut = tokenOut == tokenA_ ? reserveA_ : reserveB_;
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        require(amountIn > 0 || amountOut > 0, 'SimpleSwap: INSUFFICIENT_INPUT_AMOUNT');
        require(amountOut < reserveOut, 'SimpleSwap: INSUFFICIENT_LIQUIDITY');
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        uint256 balanceA = IERC20(tokenA_).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB_).balanceOf(address(this));
     
        require(balanceA * balanceB >= reserveA_ * reserveB_, 'UniswapV2: K');
        
        _update(balanceA, balanceB);
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    /// @notice Add liquidity to the pool
    /// @param amountAIn The amount of tokenA to add
    /// @param amountBIn The amount of tokenB to add
    /// @return amountA The actually amount of tokenA added
    /// @return amountB The actually amount of tokenB added
    /// @return liquidity The amount of liquidity minted
    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external virtual override returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        require(amountAIn>0 && amountBIn>0 , "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        (amountA, amountB) = _addLiquidity(amountAIn, amountBIn);
        IERC20(tokenA_).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB_).transferFrom(msg.sender, address(this), amountB);
        liquidity = mint(msg.sender);
        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) external virtual override returns (uint256 amountA, uint256 amountB){
        _transfer(msg.sender,address(this),liquidity);
        (amountA, amountB) = burn(msg.sender,liquidity);
    }

    /// @notice Get the reserves of the pool
    /// @return reserveA The reserve of tokenA
    /// @return reserveB The reserve of tokenB
    function getReserves() external virtual override view returns (uint256 reserveA, uint256 reserveB){
        reserveA = reserveA_;
        reserveB = reserveB_;
    }

    /// @notice Get the address of tokenA
    /// @return tokenA The address of tokenA
    function getTokenA() external virtual override view returns (address tokenA){
        tokenA = tokenA_;
    }

    /// @notice Get the address of tokenB
    /// @return tokenB The address of tokenB
    function getTokenB() external virtual override view returns (address tokenB){
        tokenB = tokenB_;
    }


      // **** ADD LIQUIDITY ****
    function _addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired
    ) internal virtual returns (uint amountA, uint amountB) {
       
        if (reserveA_ == 0 && reserveB_ == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA_, reserveB_);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB_, reserveA_);
                assert(amountAOptimal <= amountADesired);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

     // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amount0, uint256 reserve0, uint256 reserve1) internal pure returns (uint256 amount1) {
        require(amount0 > 0, 'SimpleSwap: INSUFFICIENT_AMOUNT');
        require(reserve0 > 0 && reserve1 > 0, 'SimpleSwap: INSUFFICIENT_LIQUIDITY');
        amount1 = (amount0 * reserve1) / reserve0;
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) internal returns (uint liquidity) {
        uint256 balanceA = IERC20(tokenA_).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB_).balanceOf(address(this));
        uint256 amountA = balanceA - reserveA_;
        uint256 amountB = balanceB - reserveB_;

        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            liquidity = Math.min(amountA * _totalSupply / reserveA_, amountB*(_totalSupply) / reserveB_);
        }
        require(liquidity > 0, 'SimpleSwap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balanceA, balanceB);
    }

        // this low-level function should be called from a contract which performs important safety checks
    function burn(address to,uint256 liquidity) internal returns (uint amountA, uint amountB) {
        uint256 balanceA = IERC20(tokenA_).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB_).balanceOf(address(this));
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amountA = liquidity * balanceA / _totalSupply; // using balances ensures pro-rata distribution
        amountB = liquidity * balanceB / _totalSupply; // using balances ensures pro-rata distribution
        require(amountA > 0 && amountB > 0, 'SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        IERC20(tokenA_).transfer(to, amountA);
        IERC20(tokenB_).transfer(to, amountB);
        balanceA = IERC20(tokenA_).balanceOf(address(this));
        balanceB = IERC20(tokenB_).balanceOf(address(this));

        _update(balanceA, balanceB);
    }

     // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balanceA, uint256 balanceB) private {
        reserveA_ = uint256(balanceA);
        reserveB_ = uint256(balanceB);
    }

    function isContract(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }

}

