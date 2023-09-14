// 这是个驱动FLASH的SPI串口(模式0)
/*
    SPI发：指令8bit + 地址24bit + 数据
*/

module spi_drive#(
    parameter                           P_DATA_WIDTH        = 8                 ,  
    parameter                           P_OP_LEN            = 32                ,  
    parameter                           P_CPOL              = 0                 ,   
    parameter                           P_CPHL              = 0                 ,  
    parameter                           P_READ_DATA_WIDTH   = 8                 
)(
    input                               i_clk                               ,       // 系统时钟
    input                               i_rst                               ,       // 复位
    
    output                              o_spi_clk                           ,       // spi时钟
    output                              o_spi_cs                            ,       // spi片选
    output                              o_spi_mosi                          ,       // 主机输出
    input                               i_spi_miso                          ,       // 从机输出

    input   [P_OP_LEN- 1:0]             i_user_op_data                      ,       // 操作数据：指令（8bit+地址24bit）
    input   [1:0]                       i_user_op_type                      ,       // 操作类型 0: 只传指令 1：指令和地址 2: 传指令和地址，写完地址后，得到1个脉冲(req)，接着传数据，每要传一个，就脉冲一次
    input   [15:0]                      i_user_op_len                       ,       // 操作数据的长度：32、8
    input   [15:0]                      i_user_clk_len                      ,       // 时钟周期 如果要写数据 32 + 写/读周期  8<<(字节-1)  
    input                               i_user_op_valid                     ,       // 用户的有效信号
    output                              o_user_op_ready                     ,       // 用户的准备信号 (握手后把输入锁存)

    input   [P_DATA_WIDTH-1:0]          i_user_write_data                   ,       // 写数据（用户方收到一个req就发一个byte）
    output                              o_user_write_req                    ,       // 写数据请求

    output  [P_READ_DATA_WIDTH - 1:0]   o_user_read_data                    ,       // 读数据
    output                              o_user_read_valid                           // 读数据有效
);

localparam                                      P_OP_TYPE_INS   =   0       ,
                                                P_OP_READ       =   1       ,
                                                P_OP_WRITE      =   2       ;

// 寄存输出
reg                                                     ro_spi_clk                                              ;
reg                                                     ro_spi_cs                                               ;
reg                                                     ro_spi_mosi                                             ;
reg                                                     ro_user_op_ready                                        ; 
reg                                                     ro_user_write_req                                       ;     
reg [P_READ_DATA_WIDTH - 1:0]                           ro_user_read_data                                       ;     
reg                                                     ro_user_read_valid                                      ;     


assign                                                  o_spi_clk                =     ro_spi_clk               ;
assign                                                  o_spi_cs                 =     ro_spi_cs                ;
assign                                                  o_spi_mosi               =     ro_spi_mosi              ;
assign                                                  o_user_op_ready          =     ro_user_op_ready         ;
assign                                                  o_user_write_req         =     ro_user_write_req        ;
assign                                                  o_user_read_data         =     ro_user_read_data        ;
assign                                                  o_user_read_valid        =     ro_user_read_valid       ;

// 辅助信号
reg                                                     r_run                                                   ;
reg [15:0]                                              r_cnt                                                   ;
reg                                                     r_spi_cnt                                               ;

reg [15:0]                                              r_req_cnt                                               ;       // 因为req按周期拉高

reg                                                     ro_user_write_req_1d                                    ;

reg [15:0]                                              r_read_cnt                                              ;

// 锁存输入一旦握手成功
reg [P_OP_LEN - 1:0]                                    r_user_op_data                                          ;

reg [1:0]                                               r_user_op_type                                          ;
reg [15:0]                                              r_user_op_len                                           ;
reg [15:0]                                              r_user_clk_len                                          ;

reg [P_DATA_WIDTH - 1:0]                                r_user_write_data                                       ;

// 握手
wire                                                    w_spi_active                                            ;
assign                                                  w_spi_active = i_user_op_valid & o_user_op_ready        ;

// 锁存数据 不然会丢失 还要用来做事
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst) begin
        r_user_op_type <= 'd0;
        r_user_op_len  <= 'd0;
        r_user_clk_len <= 'd0;
    end else if (w_spi_active) begin
        r_user_op_type <= i_user_op_type;
        r_user_op_len  <= i_user_op_len ;
        r_user_clk_len <= i_user_clk_len;
    end else begin
        r_user_op_type <= r_user_op_type;
        r_user_op_len  <= r_user_op_len ;
        r_user_clk_len <= r_user_clk_len;
    end
end

// 通过握手控制run 然后通过run控制计数器 通过计数器再关闭run
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_run <= 'd0;
    else if (r_spi_cnt && r_cnt == r_user_clk_len - 1)                  // 使用计数器控制run
        r_run <= 'd0;
    else if (w_spi_active)
        r_run <= 'd1;
    else
        r_run <= r_run;
end

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_spi_cnt <= 'd0;
    else if (r_run && r_spi_cnt)
        r_spi_cnt <= 'd0;
    else if (r_run)
        r_spi_cnt <= r_spi_cnt + 1;
    else 
        r_spi_cnt <= r_spi_cnt;
end

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_cnt <= 'd0;
    else if (r_run && r_spi_cnt && r_cnt == r_user_clk_len - 1)
        r_cnt <= 'd0;
    else if (r_run && r_spi_cnt)
        r_cnt <= r_cnt + 1;
    else    
        r_cnt <= r_cnt;
end 

// 生成时钟 spi_clk
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_spi_clk <= P_CPOL;
    else if (r_run)
        ro_spi_clk <= ~ro_spi_clk;
    else    
        ro_spi_clk <= P_CPOL;
end

// cs信号
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_spi_cs <= 'd1;
    else if (w_spi_active)
        ro_spi_cs <= 'd0;
    else if (!r_run)                // 这里注意优先级
        ro_spi_cs <= 'd1;
    else 
        ro_spi_cs <= ro_spi_cs;
end

// ready
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_user_op_ready <= 'd1;
    else if (w_spi_active)
        ro_user_op_ready <= 'd0;
    else if (!r_run)
        ro_user_op_ready <= 'd1;        // 同样注意优先级
    else 
        ro_user_op_ready <= ro_user_op_ready;
end

// 对输入的操作数做以下移位寄存 方便后面输出
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_user_op_data <= 'd0;
    else if (w_spi_active)
        r_user_op_data <= i_user_op_data << 1;
    else if (r_spi_cnt)
        r_user_op_data <= r_user_op_data << 1;
    else 
        r_user_op_data <= r_user_op_data;
end

// // 输出 mosi
// always@(posedge i_clk or posedge i_rst)
// begin
//     if (i_rst)
//         ro_spi_mosi <= 'd0;
//     else if (w_spi_active)  
//         ro_spi_mosi <= i_user_op_data[r_user_op_len - 1];
//     else if (r_spi_cnt)
//         ro_spi_mosi <= r_user_op_data[r_user_op_len - 1];
//     else 
//         ro_spi_mosi <= ro_spi_mosi;
// end
 
// 操作数据输出完后 看一下有没有写数据的要求 也就是req
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_user_write_req <= 'd0;
        //       因提前req 所以存在 比如40bit 最后在cnt = 39也req的话 这是多余的↓ 
    else if (                       r_cnt > r_user_clk_len - 5                     ) 
        ro_user_write_req <= 'd0;
        //          要写数据↓                为用户端输出数据等提供时序↓      时序图可见↓                 还需要考虑周期出现的情况↓  
    else if (i_user_op_type == P_OP_WRITE && r_cnt === r_user_op_len -3 &&   r_spi_cnt   ||    i_user_op_type == P_OP_WRITE && r_req_cnt == 'd15           )
        ro_user_write_req <= 'd1;
    else 
        ro_user_write_req <= 'd0;
end

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_req_cnt <= 'd0;
    else if (r_req_cnt == 'd15)
        r_req_cnt <= 'd0;
    else if (ro_user_write_req || (i_user_op_type == P_OP_WRITE && r_req_cnt > 0))
        r_req_cnt <= r_req_cnt + 1;
    else 
        r_req_cnt <= 'd0;
end

// 有了req 就要写数据了 也要在mosi上写 所以把之前的mosi扩展一下
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_spi_mosi <= 'd0;
    else if (w_spi_active)  
        ro_spi_mosi <= i_user_op_data[r_user_op_len - 1];     
    else if (r_spi_cnt && r_cnt < r_user_op_len -1)
        ro_spi_mosi <= r_user_op_data[r_user_op_len - 1];
// 在这之前都是写操作数

    else if (i_user_op_type == P_OP_WRITE && r_spi_cnt && r_cnt >= r_user_op_len -1)     // 写数据
        ro_spi_mosi <= r_user_write_data[7];
    else 
        ro_spi_mosi <= ro_spi_mosi;
end

// 如果直接用req输出mosi 就会多半个spi_clk周期
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_user_write_req_1d <= 'd0;
    else
        ro_user_write_req_1d <= ro_user_write_req;      // 打了一拍后的req用来移位data 正常的req用来控制用户方data输人
end

// 寄存输入的写数据data
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_user_write_data <= 'd0;
    else if (ro_user_write_req_1d)
        r_user_write_data <= i_user_write_data;
    else if (i_user_op_type == P_OP_WRITE && r_spi_cnt && r_cnt >= r_user_op_len -1)
        r_user_write_data <= r_user_write_data << 1;
    else 
        r_user_write_data <= r_user_write_data;
end

// 读数据 准备在这里加入一个读数据计数器
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_read_cnt <= 'd0;
    else if (r_read_cnt == P_DATA_WIDTH - 1 && r_spi_cnt)               // 注意这里 r_spi_cnt 因为数据是按照spi_clk 所以加上这个保证计数器计数正确
        r_read_cnt <= 'd0;
    else if (r_user_op_type == P_OP_READ && r_cnt >= r_user_op_len && r_spi_cnt)
        r_read_cnt <= r_read_cnt + 1;
    else 
        r_read_cnt <= r_read_cnt;
end

// 读数据 串转并输出
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_user_read_data <= 'd0;
    else if (r_cnt == r_user_clk_len - 1 && r_spi_cnt)
        ro_user_read_data <= 'd0;
    else if (r_user_op_type == P_OP_READ && r_cnt >= r_user_op_len - 1 && r_spi_cnt)
        ro_user_read_data <= {ro_user_read_data[P_DATA_WIDTH-2:0], i_spi_miso};
    else 
        ro_user_read_data <= ro_user_read_data;
end

// read_valid
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_user_read_valid <= 'd0;
    else if (r_user_op_type == P_OP_READ && r_cnt >= r_user_op_len - 1 && r_read_cnt == P_READ_DATA_WIDTH - 1 && r_spi_cnt)
        ro_user_read_valid <= 'd1;
    else 
        ro_user_read_valid <= 'd0;
end


// always@(posedge i_clk or posedge i_rst)
// begin
//     if (i_rst)

//     else if ()

//     else if ()

//     else 

// end

// always@(posedge i_clk or posedge i_rst)
// begin
//     if (i_rst)

//     else if ()

//     else if ()

//     else 

// end


endmodule

// 主要在于确定控制关系，先通过输入确定run的拉高，run为高，两个计数器开始工作，工作到一个地点，run拉低
// run就确定了，run运行过程中，对in_data做移位，同时也能控制ready，还有cs
// 有run和spi_cnt，那么mosi也能确定，读数据的valid也可以确定，spi_clk也可以确定
