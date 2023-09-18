`timescale 1ns/1ps

module flash_drive_tb();

localparam P_CLK_PERIOD_HALF = 10;

reg clk, rst;

initial begin
    clk = 0;
    rst = 1;
    #20;
    @(posedge clk)rst = 0;        // 鍚屾閲婃斁
end

always #10 clk = ~clk;

// 连线
wire [1 :0]                                                             w_operation_type                                                ;
wire [23:0]                                                             w_operation_addr                                                ;
wire [8 :0]                                                             w_operation_num                                                 ;
wire                                                                    w_operation_valid                                               ;
wire                                                                    w_operation_ready                                               ;

wire [7 :0]                                                             w_write_data                                                    ;
wire                                                                    w_write_sop                                                     ;
wire                                                                    w_write_eop                                                     ;
wire                                                                    w_write_valid                                                   ;

wire [7 :0]                                                             w_read_data                                                     ;
wire                                                                    w_read_sop                                                      ;
wire                                                                    w_read_eop                                                      ;
wire                                                                    w_read_valid                                                    ;

wire                                                                    w_spi_clk                                                       ;
wire                                                                    w_spi_cs                                                        ;
wire                                                                    w_spi_mosi                                                      ;
wire                                                                    w_spi_miso                                                      ;

flash_drive flash_drive_u0(
    .i_clk                          (clk)                                  ,//用户时钟
    .i_rst                          (rst)                                  ,//用户复位

    /*--------用户接口--------*/                // 注意调整输入和输出
    .i_operation_type               (w_operation_type )                                  ,//操作类型
    .i_operation_addr               (w_operation_addr )                                  ,//操作地址
    .i_operation_num                (w_operation_num  )                                  ,//限制用户每次最多写256字节
    .i_operation_valid              (w_operation_valid)                                  ,//操作握手有效
    .o_operation_ready              (w_operation_ready)                                  ,//操作握手准备

    .i_write_data                   (w_write_data )                                  ,//写数据
    .i_write_sop                    (w_write_sop  )                                  ,//写数据-开始信号
    .i_write_eop                    (w_write_eop  )                                  ,//写数据-结束信号
    .i_write_valid                  (w_write_valid)                                  ,//写数据-有效信号

    .o_read_data                    (w_read_data )                                  ,//读数据
    .o_read_sop                     (w_read_sop  )                                  ,//读数据-开始信号
    .o_read_eop                     (w_read_eop  )                                  ,//读数据-结束信号
    .o_read_valid                   (w_read_valid)                                  ,//读数据-有效信号

    /*--------驱动接口--------*/  
    .o_spi_clk                      (w_spi_clk )                                  ,       // spi时钟
    .o_spi_cs                       (w_spi_cs  )                                  ,       // spi片选
    .o_spi_mosi                     (w_spi_mosi)                                  ,       // 主机输出
    .i_spi_miso                     (w_spi_miso)                                          // 从机输出
);


user_gen_data user_gen_data_u0(
    .i_clk                          (clk)                                  ,
    .i_rst                          (rst)                                  ,

    /*---- 修改端口方向 ----*/
    .o_operation_type               (w_operation_type )                                  ,
    .o_operation_addr               (w_operation_addr )                                  ,
    .o_operation_num                (w_operation_num  )                                  ,
    .o_operation_valid              (w_operation_valid)                                  ,
    .i_operation_ready              (w_operation_ready)                                  ,

    .o_write_data                   (w_write_data )                                  ,
    .o_write_sop                    (w_write_sop  )                                  ,
    .o_write_eop                    (w_write_eop  )                                  ,
    .o_write_valid                  (w_write_valid)                                  ,

    .i_read_data                    (w_read_data )                                  ,
    .i_read_sop                     (w_read_sop  )                                  ,
    .i_read_eop                     (w_read_eop  )                                  ,
    .i_read_valid                   (w_read_valid)                       
);

endmodule
