// 用来上板验证的顶层文件

module spi_top(
    input                               i_clk                               ,

    output                              o_spi_clk                           ,
    output                              o_spi_cs                            ,
    output                              o_spi_mosi                          ,
    input                               i_spi_miso
);

wire                                                    w_clk_5Mhz          ;
wire                                                    w_clk_5Mhz_lock     ;              

wire                                                    w_user_ready        ;
(* mark_debug = "true" *)wire   [7:0]                   w_user_read_data    ;          // 一种vivado debug信号 一般加在内部逻辑
(* mark_debug = "true" *)wire                           w_user_read_valid   ;

// 过pll产生正常使用的clk以及内部模块的rst
SYSTEM_CLK SYSTEM_CLK_U0
(
    .clk_in1    (i_clk              ),
    .clk_out    (w_clk_5Mhz         ),
    .locked     (w_clk_5Mhz_lock    )      
    
);



spi_drive#(
    .P_DATA_WIDTH        (      8     )                 ,    
    .P_CPOL              (      0     )                 ,   
    .P_CPHL              (      0     )                 ,  
    .P_READ_DATA_WIDTH   (      8     )                 ,
)
spi_drive_u0
(
    .i_clk                 (w_clk_5Mhz          )             ,
    .i_rst                 (~w_clk_5Mhz_lock    )             ,

    .o_spi_clk             (o_spi_clk           )             ,
    .o_spi_cs              (o_spi_cs            )             ,
    .o_spi_mosi            (o_spi_mosi          )             ,
    .i_spi_miso            (i_spi_miso          )             ,     // 回环验证

    .i_user_data           (8'd55               )             ,
    .i_user_valid          (1                   )             ,
    .o_user_ready          (w_user_ready        )             ,

    .o_user_read_data      (w_user_read_data    )             ,
    .o_user_read_valid     (w_user_read_valid   )             
);


endmodule
