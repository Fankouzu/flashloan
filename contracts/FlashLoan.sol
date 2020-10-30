pragma solidity ^0.5.0;

import "./IERC20.sol";

interface pair{
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface uniRouter{
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract FlashLoan {
    
    address public router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public USDTETH = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public loanAmount;
    uint256 public ETHAmount;
    
    bytes _data = bytes("FlashLoan");
    event Balance(uint256 amount);
    
    constructor() public{
        safeApprove(WETH,router,uint(-1));
        safeApprove(USDT,router,uint(-1));
        safeApprove(USDC,router,uint(-1));
    }
    
    function deposit() public payable{
        ETHAmount = msg.value;
        IWETH(WETH).deposit.value(ETHAmount)();
        emit Balance(IERC20(WETH).balanceOf(address(this)));
    }
    
    function uniswapV2Call(address account,uint256 amount0,uint256 amount1,bytes memory data) public{
        uint256 balance = IERC20(USDT).balanceOf(address(this));
        emit Balance(balance);
        address[] memory path1 = new address[](2);
        path1[0] = USDT;
        path1[1] = USDC;
        
        uint[] memory amounts1 = uniRouter(router).swapExactTokensForTokens(balance,uint(0),path1,address(this),block.timestamp+1800);
        emit Balance(amounts1[1]);
        
        address[] memory path2 = new address[](2);
        path2[0] = USDC;
        path2[1] = WETH;
        
        uint[] memory amounts2 = uniRouter(router).swapExactTokensForTokens(amounts1[1],uint(0),path2,address(this),block.timestamp+1800);
        emit Balance(amounts2[1]);
        
        address[] memory path3 = new address[](2);
        path3[0] = WETH;
        path3[1] = USDT;
        uint[] memory amounts3 = uniRouter(router).getAmountsIn(loanAmount,path3);
        emit Balance(amounts3[0]);
        
        IERC20(WETH).transfer(USDTETH,amounts3[0]);
        
        emit Balance(ETHAmount - amounts3[0]);
    }
    
    function swap(uint256 _loanAmount) public {
        loanAmount = _loanAmount;
        pair(USDTETH).swap(uint(0),_loanAmount,address(this),_data);
    }
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }
}