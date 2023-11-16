// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {

    // Implement core logic here
     // Implement core logic here
    address public tokenA_;
    address public tokenB_;
    uint256 public reserveA_;
    uint256 public reserveB_;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint32  private blockTimestampLast;
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;

    constructor(address _tokenA, address _tokenB) ERC20("LP TOKEN", "LP") {
        require(isContract(_tokenA),"SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(isContract(_tokenB),"SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA!=_tokenB,"SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        tokenA_ = _tokenA;
        tokenB_ = _tokenB;
    }

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) 
        external virtual override returns (uint256 amountOut) {
        
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
        (amountA, amountB) = _addLiquidity(amountAIn, amountBIn);
        IERC20(tokenA_).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB_).transferFrom(msg.sender, address(this), amountB);
        liquidity = mint(msg.sender);
    }

 /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) external virtual override returns (uint256 amountA, uint256 amountB){
        console.log(allowance(msg.sender,address(this)));
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
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA*reserveB) / reserveA;
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
           //_mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amountA * _totalSupply / reserveA_, amountB*(_totalSupply) / reserveB_);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balanceA, balanceB);
        //if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        //emit Mint(msg.sender, amount0, amount1);
    }

        // this low-level function should be called from a contract which performs important safety checks
    function burn(address to,uint256 liquidity) internal returns (uint amountA, uint amountB) {
        uint256 balanceA = IERC20(tokenA_).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB_).balanceOf(address(this));
        //uint256 liquidity = balanceOf(address(this));

        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amountA = liquidity * balanceA / _totalSupply; // using balances ensures pro-rata distribution
        amountB = liquidity * balanceB / _totalSupply; // using balances ensures pro-rata distribution
        require(amountA > 0 && amountB > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        IERC20(tokenA_).transfer(to, amountA);
        IERC20(tokenB_).transfer(to, amountB);
        balanceA = IERC20(tokenA_).balanceOf(address(this));
        balanceB = IERC20(tokenB_).balanceOf(address(this));

        _update(balanceA, balanceB);
        //if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        //emit Burn(msg.sender, amount0, amount1, to);
    }

     // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balanceA, uint256 balanceB) private {
        //require(balanceA <= uint256(-1) && balanceB <= uint256(-1), 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && reserveA_ != 0 && reserveB_ != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += (reserveB_/reserveA_)*timeElapsed;
            price1CumulativeLast += (reserveA_/reserveB_)*timeElapsed;
            //price0CumulativeLast += uint(UQ112x112.encode(reserveB_).uqdiv(reserveA_)) * timeElapsed;
            //price1CumulativeLast += uint(UQ112x112.encode(reserveA_).uqdiv(reserveB_)) * timeElapsed;
        }
        reserveA_ = uint256(balanceA);
        reserveB_ = uint256(balanceB);
        blockTimestampLast = blockTimestamp;
        //emit Sync(reserveA_, reserveB_);1
    }

    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

}

