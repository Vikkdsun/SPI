// FLASH驱动器，这是顶层模块
/*
    之前已经写好了相互关联的FLASH_CTRL和SPI_DRIVE模块，二者都是FLASH_DRIVE内部的小模块。
    FLASH_DRIVE模块包含了此二者，是最终的大模块，外部直接连接FLASH。

    其接口包含了FLASH_CTRL的用户端口输入输出和SPI_DRIVE的给FLASH的SPI端口。
*/

module flash_drive(
    input                               i_clk                               ,//用户时钟
    input                               i_rst                               ,//用户复位

    /*--------用户接口--------*/                // 注意调整输入<---->输出
    output  [1 :0]                      o_operation_type                    ,//操作类型
    output  [23:0]                      o_operation_addr                    ,//操作地址
    output  [8 :0]                      o_operation_num                     ,//限制用户每次最多写256字节
    output                              o_operation_valid                   ,//操作握手有效
    input                               i_operation_ready                   ,//操作握手准备

    output  [P_DATA_WIDTH - 1 :0]       o_write_data                        ,//写数据
    output                              o_write_sop                         ,//写数据-开始信号
    output                              o_write_eop                         ,//写数据-结束信号
    output                              o_write_valid                       ,//写数据-有效信号

    input [P_DATA_WIDTH - 1 :0]         i_read_data                         ,//读数据
    input                               i_read_sop                          ,//读数据-开始信号
    input                               i_read_eop                          ,//读数据-结束信号
    input                               i_read_valid                        ,//读数据-有效信号

    /*--------驱动接口--------*/  
    input                               i_spi_clk                           ,       // spi时钟
    input                               i_spi_cs                            ,       // spi片选
    input                               i_spi_mosi                          ,       // 主机输出
    output                              o_spi_miso                                  // 从机输出
);

// 连线
wire [31:0]                             w_user_op_data                      ;
wire [1:0]                              w_user_op_type                      ;
wire [15:0]                             w_user_op_len                       ;
wire [15:0]                             w_user_clk_len                      ;
wire                                    w_user_op_valid                     ;
wire                                    w_user_op_ready                     ;

wire [7:0]                              w_user_write_data                   ;
wire                                    w_user_write_req                    ;
wire [7:0]                              w_user_read_data                    ;
wire                                    w_user_read_valid                   ;

// 对两个主要模块进行例化
flash_ctrl#(
        .P_DATA_WIDTH       (       8           )                   ,//数据位宽
        .P_OP_LEN           (       32          )                   ,//指令长度
        .P_READ_DATA_WIDTH  (       8           )                   ,//读数据位�?
        .P_CPOL             (       0           )                   ,//空闲时时钟状�?
        .P_CPHL             (       0           )                    //采集数据时钟�?
)   
flash_ctrl_u0
(
    .i_clk                  (i_clk              )                   ,//用户时钟
    .i_rst                  (i_rst              )                   ,//用户复位

    /*--------用户接口--------*/    
    .i_operation_type       (o_operation_type   )                   ,//操作类型
    .i_operation_addr       (o_operation_addr   )                   ,//操作地址
    .i_operation_num        (o_operation_num    )                   ,//限制用户每次最多写256字节
    .i_operation_valid      (o_operation_valid  )                   ,//操作握手有效
    .o_operation_ready      (i_operation_ready  )                   ,//操作握手准备

    .i_write_data           (o_write_data       )                   ,//写数据
    .i_write_sop            (o_write_sop        )                   ,//写数据-开始信号
    .i_write_eop            (o_write_eop        )                   ,//写数据-结束信号
    .i_write_valid          (o_write_valid      )                   ,//写数据-有效信号

    .o_read_data            (i_read_data        )                   ,//读数据
    .o_read_sop             (i_read_sop         )                   ,//读数据-开始信号
    .o_read_eop             (i_read_eop         )                   ,//读数据-结束信号
    .o_read_valid           (i_read_valid       )                   ,//读数据-有效信号

    /*--------驱动接口--------*/    
    .o_user_op_data         (w_user_op_data     )                   ,//操作数据（指令8bit+地址24bit）
    .o_user_op_type         (w_user_op_type     )                   ,//操作类型（读、写、指令）
    .o_user_op_len          (w_user_op_len      )                   ,//操作数据的长度32、8
    .o_user_clk_len         (w_user_clk_len     )                   ,//时钟周期
    .o_user_op_valid        (w_user_op_valid    )                   ,//用户的有效信号
    .i_user_op_ready        (w_user_op_ready    )                   ,//用户的准备信号

    .o_user_write_data      (w_user_write_data  )                   ,//写数据
    .i_user_write_req       (w_user_write_req   )                   ,//写数据请求
                    
    .i_user_read_data       (w_user_read_data   )                   ,//读数据
    .i_user_read_valid      (w_user_read_valid  )                    //读数据有效
);


spi_drive#(
    .P_DATA_WIDTH           (       8           )                   ,  
    .P_OP_LEN               (       32          )                   ,  
    .P_CPOL                 (       0           )                   ,   
    .P_CPHL                 (       0           )                   ,  
    .P_READ_DATA_WIDTH      (       8           )                   
)
spi_drive_u0
(
    .i_clk                  (i_clk              )                   , // 系统时钟
    .i_rst                  (i_rst              )                   , // 复位

    .o_spi_clk              (i_spi_clk          )                   ,       // spi时钟
    .o_spi_cs               (i_spi_cs           )                   ,       // spi片选
    .o_spi_mosi             (i_spi_mosi         )                   ,       // 主机输出
    .i_spi_miso             (o_spi_miso         )                   ,       // 从机输出
 
    .i_user_op_data         (w_user_op_data     )                   ,       // 操作数据：指令（8bit+地址24bit）
    .i_user_op_type         (w_user_op_type     )                   ,       // 操作类型 0: 只传指令 1：指令和地址 2: 传指令和地址，写完地址后，得到1个脉冲(req)，接着传数据，每要传一个，就脉冲一次
    .i_user_op_len          (w_user_op_len      )                   ,       // 操作数据的长度：32、8
    .i_user_clk_len         (w_user_clk_len     )                   ,       // 时钟周期 如果要写数据 32 + 写/读周期  8<<(字节-1)  
    .i_user_op_valid        (w_user_op_valid    )                   ,       // 用户的有效信号
    .o_user_op_ready        (w_user_op_ready    )                   ,       // 用户的准备信号 (握手后把输入锁存)

    .i_user_write_data      (w_user_write_data  )                   ,       // 写数据（用户方收到一个req就发一个byte）
    .o_user_write_req       (w_user_write_req   )                   ,       // 写数据请求

    .o_user_read_data       (w_user_read_data   )                   ,       // 读数据
    .o_user_read_valid      (w_user_read_valid  )                           // 读数据有效
);

endmodule

/*
    没什么难的，主要是前期的内部小模块分的比较清楚，接口比较清晰这里只需要连线
    分清输出输入
    输入变输出，输出变输入，学会这种思想
*/
