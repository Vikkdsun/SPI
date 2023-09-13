`timescale 1ns/1ps

module spi_drive_tb();

localparam P_CLK_PERIOD_HALF = 10;

reg clk, rst;

initial begin
    rst = 'd1;
    #100;
    @(posedge clk)rst = 'd0;        // 同步释放
end

always
begin
    clk = 0;
    #P_CLK_PERIOD_HALF;
    clk = 1;
    #P_CLK_PERIOD_HALF;
end

wire                w_spi_clk           ;
wire                w_spi_cs            ;
wire                w_spi_mosi          ;
wire                w_user_ready        ;
wire   [7:0]        w_user_read_data    ;
wire                w_user_read_valid   ;

reg    [7:0]        r_user_data         ;
reg                 r_user_valid        ;

spi_drive#(
    .P_DATA_WIDTH        (      8     )                 ,    
    .P_CPOL              (      0     )                 ,   
    .P_CPHL              (      0     )                 ,  
    .P_READ_DATA_WIDTH   (      8     )                 ,
)
spi_drive_u0
(
    .i_clk                 (clk                 )             ,
    .i_rst                 (rst                 )             ,

    .o_spi_clk             (w_spi_clk           )             ,
    .o_spi_cs              (w_spi_cs            )             ,
    .o_spi_mosi            (w_spi_mosi          )             ,
    .i_spi_miso            (w_spi_mosi          )             ,     // 回环验证

    .i_user_data           (8'd55               )             ,
    .i_user_valid          (1                   )             ,
    .o_user_ready          (w_user_ready        )             ,

    .o_user_read_data      (w_user_read_data    )             ,
    .o_user_read_valid     (w_user_read_valid   )             
);

endmodule

