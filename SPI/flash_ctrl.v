// 一个ctrl模块 为的是联合用户和spi串口
/*
    用户方面：
        用户方输入想要做的操作、操作的地址、要写的数据数量  这些是参数级的输入
        具体的输入就是输入的上面三个参数同步的一个valid信号、
        以及要写的数据，因为要写的数据可能很多，所以存在一个开始和停止，以及在开始和停止之间的这段一直拉高的valid

        输出给用户的就是读到的数据、以及可能读到的很多，所以有开始结束和这段内高的valid
    
    SPI接口方面：
        SPI输入给本模块的是读到的数据和valid信号，这和用户得到的数据不同，这个不是连续的，valid一个脉冲，脉冲对应的数据
        还有SPI发出来的req用来写数据
        以及SPI发出来的ready

        输出给SPI的是操作数据、操作类型、操作数据长度、需要的时钟长度、有效信号

*/
module flash_ctrl#(
        parameter                           P_DATA_WIDTH        = 8 ,//数据位宽
                                            P_OP_LEN            = 32,//指令长度
                                            P_READ_DATA_WIDTH   = 8 ,//读数据位宽
                                            P_CPOL              = 0 ,//空闲时时钟状态
                                            P_CPHL              = 0  //采集数据时钟沿
)(
    input                               i_clk                   ,//用户时钟
    input                               i_rst                   ,//用户复位

    /*--------用户接口--------*/    
    input  [1 :0]                       i_operation_type        ,//操作类型
    input  [23:0]                       i_operation_addr        ,//操作地址
    input  [8 :0]                       i_operation_num         ,//限制用户每次最多写256字节
    input                               i_operation_valid       ,//操作握手有效
    output                              o_operation_ready       ,//操作握手准备

    input  [P_DATA_WIDTH - 1 :0]        i_write_data            ,//写数据
    input                               i_write_sop             ,//写数据-开始信号
    input                               i_write_eop             ,//写数据-结束信号
    input                               i_write_valid           ,//写数据-有效信号

    output [P_DATA_WIDTH - 1 :0]        o_read_data             ,//读数据
    output                              o_read_sop              ,//读数据-开始信号
    output                              o_read_eop              ,//读数据-结束信号
    output                              o_read_valid            ,//读数据-有效信号

    /*--------驱动接口--------*/    
    output   [P_OP_LEN - 1 :0]          o_user_op_data          ,//操作数据（指令8bit+地址24bit）
    output   [1 :0]                     o_user_op_type          ,//操作类型（读、写、指令）
    output   [15:0]                     o_user_op_len           ,//操作数据的长度32、8
    output   [15:0]                     o_user_clk_len          ,//时钟周期
    output                              o_user_op_valid         ,//用户的有效信号
    input                               i_user_op_ready         ,//用户的准备信号

    output  [P_DATA_WIDTH - 1 :0]       o_user_write_data       ,//写数据
    input                               i_user_write_req        ,//写数据请求

    input   [P_READ_DATA_WIDTH - 1:0]   i_user_read_data        ,//读数据
    input                               i_user_read_valid        //读数据有效
);
/*
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)

    else if ()

    else if ()

    else 
    
end
*/
// 输出锁存assign
reg                                                                             ro_operation_ready                                                              ; 
reg [P_DATA_WIDTH - 1 :0]                                                       ro_read_data                                                                    ; 
reg                                                                             ro_read_sop                                                                     ; 
reg                                                                             ro_read_eop                                                                     ; 
reg                                                                             ro_read_valid                                                                   ; 
reg [P_OP_LEN - 1 :0]                                                           ro_user_op_data                                                                 ; 
reg [1 :0]                                                                      ro_user_op_type                                                                 ; 
reg [15:0]                                                                      ro_user_op_len                                                                  ;     
reg [15:0]                                                                      ro_user_clk_len                                                                 ;         
reg                                                                             ro_user_op_valid                                                                ;     
reg [P_DATA_WIDTH - 1 :0]                                                       ro_user_write_data       // 这个没用上 因为FIFO输出需要wire                                                           ;   

// 看ready(spi)上升沿
reg                                                                             ri_user_op_ready                                                                ;

// 状态机
reg [7:0]                                                                       r_st_current                                                                    ;
reg [7:0]                                                                       r_st_next                                                                       ;

// 状态寄存器 用来记当前状态进行了多久
reg [15:0]                                                                      r_st_cnt                                                                        ;

// 对输入FIFO的信号打一拍
reg [P_DATA_WIDTH - 1 :0]                                                       ri_write_data                                                                   ;
reg                                                                             ri_write_valid                                                                  ;
reg [P_READ_DATA_WIDTH - 1:0]                                                   ri_user_read_data                                                               ;
reg                                                                             ri_user_read_valid                                                              ;   // 这里这个没用了

// FIFO的读数据使能（读数据type）
reg                                                                             r_fifo_read_rden                                                                ;

// 一个正确的 在读数据时的写使能
reg                                                                             r_fifo_read_wren                                                                ;

// 打拍empty判断上升沿
reg                                                                             r_fifo_read_empty_1d                                                            ;

// 为了读使能上升沿
reg                                                                             r_fifo_read_rden_1d                                                             ;


// 与用户握手
wire                                                                            w_user_operation_active                                                         ;
// 与spi握手
wire                                                                            w_spi_operation_active                                                          ;
// 监测ready(spi)上升沿
wire                                                                            w_user_op_ready_pos                                                             ;
// 监测empty上升沿
wire                                                                            w_fifo_read_empty_pos                                                           ;
// 监测读使能上升沿
wire                                                                            w_fifo_read_rden_pos                                                            ;

// 借助empty决定eop 和读使能
wire                                                                            w_fifo_read_empty                                                               ;

// 读数据时 对fifo输出连线 为了后面打拍
wire [P_DATA_WIDTH - 1 :0]                                                      w_fifo_read_data                                                                ;

assign                                                                          o_operation_ready  = ro_operation_ready                                         ;
assign                                                                          o_read_data        = ro_read_data                                               ;
assign                                                                          o_read_sop         = ro_read_sop                                                ;
assign                                                                          o_read_eop         = ro_read_eop                                                ;
assign                                                                          o_read_valid       = ro_read_valid                                              ;
assign                                                                          o_user_op_data     = ro_user_op_data                                            ;
assign                                                                          o_user_op_type     = ro_user_op_type                                            ;
assign                                                                          o_user_op_len      = ro_user_op_len                                             ;
assign                                                                          o_user_clk_len     = ro_user_clk_len                                            ;
assign                                                                          o_user_op_valid    = ro_user_op_valid                                           ;
assign                                                                          o_user_write_data  = ro_user_write_data                                         ;
// 监测ready(spi)上升沿 
assign                                                                          w_user_op_ready_pos= !ri_user_op_ready & i_user_op_ready                        ;
// 判断empty的上升沿
assign                                                                          w_fifo_read_empty_pos = !r_fifo_read_empty_1d & w_fifo_read_empty               ;
// 监测读使能上升沿
assign                                                                          w_fifo_read_rden_pos  = !r_fifo_read_rden_1d & r_fifo_read_rden                 ;

// 状态机参数
localparam                                                                      P_IDLE          =   0                                                               ,
                                                                                P_RUN           =   1                                                               ,
                                                                                P_W_EN          =   2                                                               ,
                                                                                P_W_INS         =   3                                                               ,
                                                                                P_W_DATA        =   4                                                               ,
                                                                                P_W_CLEAR       =   5                                                               ,
                                                                                P_R_INS         =   6                                                               ,
                                                                                P_R_DATA        =   7                                                               ,
                                                                                P_BUSY          =   8                                                               ,
                                                                                P_BUSY_CHECK    =   9                                                               ,
                                                                                P_BUSY_WAIT     =   10                                                              ;

// 操作类型tyep参数 
localparam                                                                      P_TYPE_CLEAR    =   0                                                               ,
                                                                                P_TYPE_WRITE    =   1                                                               ,
                                                                                P_TYPE_READ     =   2                                                               ;

// 传递给spi的类型
localparam                                                                      P_OP_TYPE_INS   =   0                                                               ,
                                                                                P_OP_READ       =   1                                                               ,
                                                                                P_OP_WRITE      =   2                                                               ;



// 先和用户握手
assign                                                                          w_user_operation_active = o_operation_ready & i_operation_valid                 ;
// 和spi握手
assign                                                                          w_spi_operation_active  = i_user_op_ready & o_user_op_valid                     ;

// 把短暂的一周期输入锁存
reg [1 :0]                                                                      ri_operation_type                                                               ;
reg [23:0]                                                                      ri_operation_addr                                                               ;
reg [8 :0]                                                                      ri_operation_num                                                                ;

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst) begin
        ri_operation_type <= 'd0;
        ri_operation_addr <= 'd0;
        ri_operation_num  <= 'd0;
    end else if (w_user_operation_active) begin
        ri_operation_type <= i_operation_type;
        ri_operation_addr <= i_operation_addr;
        ri_operation_num  <= i_operation_num ;
    end else begin
        ri_operation_type <= ri_operation_type;
        ri_operation_addr <= ri_operation_addr;
        ri_operation_num  <= ri_operation_num ;
    end 
end


/*================================================================== <<< 做一个状态机方便后面操作 >>> ==================================================================*/
// 第一段
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_st_current <= P_IDLE;
    else    
        r_st_current <= r_st_next;
end

// 第二段
always@(*)
begin
    case(r_st_current)
        P_IDLE          :   r_st_next   =   w_user_operation_active             ?   P_RUN       :       P_IDLE              ;
        P_RUN           :   r_st_next   =   ri_operation_type == P_TYPE_READ    ?   P_R_INS     :       P_W_EN              ;
        P_W_EN          :   r_st_next   =   w_spi_operation_active              ?   ri_operation_type == P_TYPE_CLEAR   ?   P_W_CLEAR   :   P_W_INS     :   P_W_EN          ;
        P_W_INS         :   r_st_next   =   w_spi_operation_active              ?   P_W_DATA    :       P_W_INS             ;
        // 怎么从写数据转移出去？看看写没写完 这里使用ready(spi)最好 但是小心ready自保持的 所以看上升沿
        P_W_DATA        :   r_st_next   =   w_user_op_ready_pos                 ?   P_BUSY      :       P_W_DATA            ;
        P_W_CLEAR       :   r_st_next   =   w_spi_operation_active              ?   P_BUSY      :       P_W_CLEAR           ;
        P_R_INS         :   r_st_next   =   w_spi_operation_active              ?   P_R_DATA    :       P_R_INS             ;
        P_R_DATA        :   r_st_next   =   w_user_op_ready_pos                 ?   P_BUSY      :       P_R_DATA            ;
        P_BUSY          :   r_st_next   =   w_user_op_ready_pos                 ?   P_BUSY_CHECK:       P_BUSY              ;
        P_BUSY_CHECK    :   r_st_next   =   i_user_read_valid                   ?   i_user_read_data[0]                 ?   P_BUSY_WAIT  :   P_IDLE     :   P_BUSY_CHECK    ;
        // 如果进入到忙就要等 需要一个计数器
        P_BUSY_WAIT     :   r_st_next   =   r_st_cnt == 'd255                   ?   P_IDLE      :       P_BUSY_WAIT         ;
        default         :   r_st_next   =   P_IDLE;
    endcase
end

// 监测ready(spi)上升沿
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ri_user_op_ready <= 'd1;
    else    
        ri_user_op_ready <= i_user_op_ready;
end

// 状态寄存器
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_st_cnt <= 'd0;
    else if (r_st_current != r_st_next)
        r_st_cnt <= 'd0;
    else
        r_st_cnt <= r_st_cnt + 1;
end

// 第三段状态机 关乎于输出 主要是给spi方的
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst) begin
        ro_user_op_data  <= 'd0;
        ro_user_op_type  <= 'd0;
        ro_user_op_len   <= 'd0;
        ro_user_clk_len  <= 'd0;
        ro_user_op_valid <= 'd0;
    end else if (r_st_current == P_W_EN) begin
        ro_user_op_data  <= {8'h06,8'h00,8'h00,8'h00};
        ro_user_op_type  <= P_OP_TYPE_INS;
        ro_user_op_len   <= 'd8;
        ro_user_clk_len  <= 'd8;
        ro_user_op_valid <= 'd1;
    end else if (r_st_current == P_W_INS) begin
        ro_user_op_data  <= {8'h03,ri_operation_addr};
        ro_user_op_type  <= P_OP_WRITE;
        ro_user_op_len   <= 'd32;
        ro_user_clk_len  <= 32 + 8 * ri_operation_num;      // 因为到达写数据这一步 只有一次握手 所以 输出时钟要考虑到写数据需要时钟
        ro_user_op_valid <= 'd1;
    end else if (r_st_current == P_W_CLEAR) begin           // 写数据不需要给spi东西 spi会通过req向本模块要
        ro_user_op_data  <= {8'h20,ri_operation_addr};
        ro_user_op_type  <= P_OP_TYPE_INS;
        ro_user_op_len   <= 'd32;
        ro_user_clk_len  <= 'd32;      
        ro_user_op_valid <= 'd1;
    end else if (r_st_current == P_R_INS) begin           // 写数据不需要给spi东西 spi会通过req向本模块要
        ro_user_op_data  <= {8'h03,ri_operation_addr};
        ro_user_op_type  <= P_OP_READ;
        ro_user_op_len   <= 'd32;
        ro_user_clk_len  <= 32 + 8 * ri_operation_num;      // 同写
        ro_user_op_valid <= 'd1;
    end else if (r_st_current == P_BUSY) begin           // 写数据不需要给spi东西 spi会通过req向本模块要
        ro_user_op_data  <= {8'h05,24'd0};
        ro_user_op_type  <= P_OP_READ;
        ro_user_op_len   <= 'd8;
        ro_user_clk_len  <= 'd16;      // 读忙只需要发指令 然后自动读寄存器 8+8
        ro_user_op_valid <= 'd1;       // 所有的状态 valid都自保持 为了等待ready恢复 然后握手
    end else begin
        ro_user_op_data   <= ro_user_op_data  ;
        ro_user_op_type   <= ro_user_op_type  ;
        ro_user_op_len    <= ro_user_op_len   ;
        ro_user_clk_len   <= ro_user_clk_len  ;
        ro_user_op_valid  <= 'd0 ;
    end
end

// 至此 从用户发指令到SPI已经完成 然后是发数据给SPI和从SPI读数据



/*================================================================== <<< 使用FIFO联系SPI和数据 >>> ==================================================================*/

/*----------------------<<< 第一个FIFO >>>---------------------------*/

// 为了收到SPI的req就能从本模块发送数据给SPI 这里采用FIFO
FLASH_CTRL_FIFO_DATA FLASH_CTRL_FIFO_DATA_U0 (
    .clk      (i_clk                ),  
    .srst     (i_rst                ),  
    .din      (ri_write_data        ),               // 注意 输入到FIFO的数据要打一拍
    .wr_en    (ri_write_valid       ),  
    .rd_en    (i_user_write_req     ),            // 读使能（SPI什么时候可以取数据）  答：req
    .dout     (o_user_write_data    ),               // FIFO输出要是wire型
    .full     (),                           // 由于写数据和写多少是用户决定的 然后在一开始就传给spi时钟数 所以不会存在spi要数据时没有数据 或者FIFO满了 不能写的情况
    .empty    ()  
);

// 打拍
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst) begin
        ri_write_data  <= 'd0;
        ri_write_valid <= 'd0;
    end else begin
        ri_write_data  <= i_write_data  ;
        ri_write_valid <= i_write_valid ;
    end
end

/*----------------------<<< 第二个FIFO >>>---------------------------*/

// 这个FIFO用来保存SPI读到的数据 因为FIFO读的数据 是一会一个 最后给用户要连续的 所以使用一个FIFO
FLASH_CTRL_FIFO_DATA FLASH_CTRL_FIFO_DATA_READ_U0 (
    .clk      (i_clk), 
    .srst     (i_rst), 
    .din      (ri_user_read_data),           // 同样要打拍
    .wr_en    (r_fifo_read_wren),         // 什么时候可以读？valid 但是要注意 有一个读是读忙 是不需要往这里面写的 因为他就一个数据 在busy_check就读了 如果也写这里 后面读就读寄存器了
    .rd_en    (r_fifo_read_rden), 
    .dout     (w_fifo_read_data), 
    .full     (),    
    .empty    (w_fifo_read_empty)                            // 这里借助一下empty 为了确定什么时候结束读(感觉这里不用empty 用输入给的num也可以确定什么时候不读)
);

// 一个正确的 在读数据时的写使能
// r_fifo_read_wren
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_fifo_read_wren <= 'd0;
    else if (r_st_current == P_R_DATA)
        r_fifo_read_wren <= i_user_read_valid;      // 因为输出读数据时是和spi_clk一样是两个clk周期的 所以打一拍也没事 在spi那里 valid是数据前半（一个clk周期）拉高的
    else 
        r_fifo_read_wren <= 'd0;
end

// 打拍
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst) begin
        ri_user_read_data  <= 'd0;
        ri_user_read_valid <= 'd0;
    end else begin
        ri_user_read_data  <= i_user_read_data  ;
        ri_user_read_valid <= i_user_read_valid ;
    end
end

// 什么时候开始读数据 （把写进FIFO的读到的数据 输出出来）
// 第一反应是借助spi发出来的ready的上升沿 也可以使用状态转移
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_fifo_read_rden <= 'd0;
    else if (w_fifo_read_empty_pos)         // 检测到读空的上升沿 就不读了 即使这样 也是可以读到最后一个字节的 所以没问题
        r_fifo_read_rden <= 'd0;
    else if (ri_operation_type == P_TYPE_READ && w_user_op_ready_pos)
        r_fifo_read_rden <= 'd1;
    // else if (r_st_current == P_R_DATA && r_st_next != P_R_DATA)
    //     r_fifo_read_rden <= 'd1;             // 用状态转移方法 和上面方法相同其实
    else 
        r_fifo_read_rden <= r_fifo_read_rden;
end



/*================================================================== <<< 一些输出 >>> ==================================================================*/



// 借助empty决定eop 和读使能（这里读使能不应该是脉冲 因为要连续读很多数据）
// w_fifo_read_empty

// 读数据这里输出和fifo的empty和eop sop之间的时序
/*
                                        最后一个字节时拉高
    w_fifo_read_empty           ：  ____________|--------------------------------------------

    o_read_data(从fifo读)       ：  二二二二X二二二X二二二二二二二二二二二二二二二二二二二二二二二二            // 当从fifo读最后一个字节时 empty同时变高

    o_read_sop                  ：  _______|-|________________________________________________

    o_read_eop                  ：  ____________|-|___________________________________________

    o_read_valid                ：  _______|------|___________________________________________

    这样的话 eop和valid就无法根据empty做处理
    所以 我们对从fifo读出来的数据打一拍在作为模块的输出

    于是 时序如下（加上读使能）：
                                        比数据早一个周期拉高 和数据同时拉低↓
    r_fifo_read_rden                    :   _____|-------|_________________________________________
                                
    w_fifo_read_empty                   ：  ____________|--------------------------------------------

    o_read_data(从fifo读)               ：  二二二二X二二二X二二二二二二二二二二二二二二二二二二二二二二二二

    o_read_data(最后输出)                ：  二二二二二X二二二X二二二二二二二二二二二二二二二二二二二二二二二二
    
    o_read_sop                          ：  _________|-|________________________________________________

    o_read_eop                          ：  _____________|-|___________________________________________

    o_read_valid                        ：  _________|------|___________________________________________

    这样的话 eop和valid都有依靠了

*/ 

// 所以做fifo输出他打拍再连到输出
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_read_data <= 'd0;
    else
        ro_read_data  <= w_fifo_read_data;
end

// 然后控制sop和eop
// sop和读使能上生沿有关系 但是比读使能慢一下 
// 所以创造寄存器 再要rden的上升沿
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_fifo_read_rden_1d <= 'd0;
    else
        r_fifo_read_rden_1d  <= r_fifo_read_rden;
end

// sop
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_read_sop <= 'd0;
    else if (w_fifo_read_rden_pos)
        ro_read_sop <= 'd1;
    else 
        ro_read_sop <= 'd0;
end

// eop 
// eop和empty上生沿有关系
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_read_eop <= 'd0;
    else if (w_fifo_read_empty_pos)
        ro_read_eop <= 'd1;
    else 
        ro_read_eop <= 'd0;
end

// valid
// valid和上二者有关系
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_read_valid <= 'd0;
    else if (ro_read_eop)
        ro_read_valid <= 'd0;
    else if (w_fifo_read_rden_pos)
        ro_read_valid <= 'd1;
    else
        ro_read_valid <= ro_read_valid;
end

// ro_operation_ready
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_operation_ready <= 'd1;
    else if (r_st_current == P_IDLE)
        ro_operation_ready <= 'd1;
    else if (w_user_operation_active)
        ro_operation_ready <= 'd0;
    else
        ro_operation_ready <= ro_operation_ready;
end



endmodule


/*
    难点在于既要分开用户和spi也要联系二者 
    先写状态机后就清晰很多 
    fifo也很重要 使能信号要好好分析
    最后输出的读到的数据要打一拍这个也很重要
*/
