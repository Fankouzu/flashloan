pragma solidity ^0.5.12;

import "./IERC20.sol";

interface pair{
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
}

interface router{
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts); 
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract FlashLoan {
    address public USDTETH = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    // address public USDTUSDC = 0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f;
    // address public USDCETH = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    bytes _calldata = bytes("FlashLoan");
    event Balance(address asset, uint256 amount);

    uint256 loanAmount;
    uint256 amountIn;
    
    constructor() public{
        safeApprove(WETH,uniV2,uint256(-1));
        safeApprove(USDT,uniV2,uint256(-1));
        safeApprove(USDC,uniV2,uint256(-1));
    }
    function() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }
    function deposit()public payable{
        amountIn = address(this).balance;
        IWETH(WETH).deposit.value(amountIn)();
    }
    function withdraw()public{
        uint256 balance = IERC20(WETH).balanceOf(address(this));
        emit Balance(address(this), balance);
        IWETH(WETH).withdraw(balance);
        emit Balance(address(this), address(this).balance);
        msg.sender.transfer(balance);
        amountIn = 0;
    }
    
    function paths()public view 
    returns(
        address[] memory path1,
        address[] memory path2,
        address[] memory path3,
        address[] memory path4,
        address[] memory path5,
        address[] memory path6
    ){
        path1 = new address[](2);
        path1[0] = USDT;
        path1[1] = USDC;
        path2 = new address[](2);
        path2[0] = USDC;
        path2[1] = WETH;
        path3 = new address[](2);
        path3[0] = WETH;
        path3[1] = USDT;
        path4 = new address[](2);
        path4[0] = USDT;
        path4[1] = WETH;
        path5 = new address[](2);
        path5[0] = WETH;
        path5[1] = USDC;
        path6 = new address[](2);
        path6[0] = USDC;
        path6[1] = USDT;
    }
    
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes memory data) public{
        uint balance = IERC20(USDT).balanceOf(address(this));
        emit Balance(USDT,balance);
        
        (address[] memory path1,address[] memory path2,address[] memory path3,,,) = paths();
        
        uint[] memory amounts1 = router(uniV2).swapExactTokensForTokens(loanAmount,uint(0),path1,address(this),block.timestamp+1800);
        emit Balance(USDC,amounts1[1]);
        
        uint[] memory amounts2 = router(uniV2).swapExactTokensForTokens(amounts1[1],uint(0),path2,address(this),block.timestamp+1800);
        emit Balance(WETH,amounts2[1]);
        
        
        uint[] memory amounts3 = router(uniV2).getAmountsIn(loanAmount, path3);
        
        IERC20(WETH).transfer(USDTETH,amounts3[0]);
        
        emit Balance(WETH,IERC20(WETH).balanceOf(address(this)));
    }
    
    function swap(uint256 _loanAmount) public{
        loanAmount = _loanAmount;
        pair(USDTETH).swap(uint(0),loanAmount,address(this),_calldata);
        emit Balance(WETH,amountIn - IERC20(WETH).balanceOf(address(this)));
    }
    
    function calcA(uint256 _amountIn) public view returns(uint256){
        (address[] memory path1,address[] memory path2,address[] memory path3,,,) = paths();
        
        uint[] memory amounts1 = router(uniV2).getAmountsOut(_amountIn, path3);
        uint[] memory amounts2 = router(uniV2).getAmountsOut(amounts1[1], path1);
        uint[] memory amounts3 = router(uniV2).getAmountsOut(amounts2[1], path2);
        return _amountIn - amounts3[1];
    }
    
    function calcB(uint256 _amountIn) public view returns(uint256){
        (,,,address[] memory path4,address[] memory path5,address[] memory path6) = paths();
        
        uint[] memory amounts1 = router(uniV2).getAmountsOut(_amountIn, path5);
        uint[] memory amounts2 = router(uniV2).getAmountsOut(amounts1[1], path6);
        uint[] memory amounts3 = router(uniV2).getAmountsOut(amounts2[1], path4);
        return _amountIn - amounts3[1];
        
    }
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }
}