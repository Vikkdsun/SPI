// 写一个用来验证FLASH_DRIVE的用户端数据生成模块

module user_gen_data(
    input                               i_clk                               ,
    input                               i_rst                               ,

    /*---- 修改端口方向 ----*/
    output  [1 :0]                      o_operation_type                    ,
    output  [23:0]                      o_operation_addr                    ,
    output  [8 :0]                      o_operation_num                     ,
    output                              o_operation_valid                   ,
    input                               i_operation_ready                   ,

    output  [7 :0]                      o_write_data                        ,
    output                              o_write_sop                         ,
    output                              o_write_eop                         ,
    output                              o_write_valid                       ,

    input [7 :0]                        i_read_data                         ,
    input                               i_read_sop                          ,
    input                               i_read_eop                          ,
    input                               i_read_valid                        
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

// 常规寄存输出并绑定
reg [1 :0]                                                                  ro_operation_type                                                                           ;
reg [23:0]                                                                  ro_operation_addr                                                                           ;
reg [8 :0]                                                                  ro_operation_num                                                                            ;
reg                                                                         ro_operation_valid                                                                          ;
                                                                    
reg [7 :0]                                                                  ro_write_data                                                                               ;
reg                                                                         ro_write_sop                                                                                ;
reg                                                                         ro_write_eop                                                                                ;
reg                                                                         ro_write_valid                                                                              ;

// 判断ready上升沿
reg                                                                         ri_operation_ready                                                                          ;

// 状态机
reg [7:0]                                                                   r_st_current                                                                                ;
reg [7:0]                                                                   r_st_next                                                                                   ;

// 状态转移用
reg [15:0]                                                                  r_idle_cnt                                                                                  ;

// 写数据时的计数器
reg [15:0]                                                                  r_write_cnt                                                                                 ;

// 打拍write_valid
reg                                                                         r_operation_valid_1d                                                                        ;

// reg [15:0]                                                                  r_write_num_cnt                                 ;
// reg [15:0]                                                                  r_write_num_cnt                                 ;



// 握手
wire                                                                        w_operation_active                                                                          ;
// 判断ready上升沿
wire                                                                        w_operation_ready_pos                                                                       ;







assign                                                                      o_operation_type    =   ro_operation_type                                                   ;
assign                                                                      o_operation_addr    =   ro_operation_addr                                                   ;
assign                                                                      o_operation_num     =   ro_operation_num                                                    ;
assign                                                                      o_operation_valid   =   ro_operation_valid                                                  ;
assign                                                                      o_write_data        =   ro_write_data                                                       ;
assign                                                                      o_write_sop         =   ro_write_sop                                                        ;
assign                                                                      o_write_eop         =   ro_write_eop                                                        ;
assign                                                                      o_write_valid       =   ro_write_valid                                                      ;

// 握手
assign                                                                      w_operation_active  =   o_operation_valid & i_operation_ready                               ;

// 判断ready上升沿
assign                                                                      w_operation_ready_pos = !ri_operation_ready & i_operation_ready                             ;



// 考虑使用状态机为FLASH_DRIVE输入
localparam                                                                  P_ST_IDLE  = 0                                                                              ,
                                                                            P_ST_WRITE = 1                                                                              ,
                                                                            P_ST_READ  = 2                                                                              ,
                                                                            P_ST_CLEAR = 3                                                                              ;

localparam                                                                  P_TYPE_CLEAR    =   0                                                                       ,
                                                                            P_TYPE_WRITE    =   1                                                                       ,
                                                                            P_TYPE_READ     =   2                                                                       ;

// 第一段
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_st_current <= P_ST_IDLE;
    else 
        r_st_current <= r_st_next;
end

// 第二段
always@(*)
begin
    case(r_st_current)
        P_ST_IDLE   :   r_st_next   =   r_idle_cnt == 10        ?   P_ST_CLEAR  :   P_ST_IDLE       ;
        P_ST_WRITE  :   r_st_next   =   w_operation_ready_pos   ?   P_ST_READ   :   P_ST_WRITE      ;
        P_ST_READ   :   r_st_next   =   w_operation_ready_pos   ?   P_ST_IDLE   :   P_ST_READ       ;
        P_ST_CLEAR  :   r_st_next   =   w_operation_ready_pos   ?   P_ST_WRITE  :   P_ST_CLEAR      ;
        default     :   r_st_next   =   P_ST_IDLE                                                   ;
    endcase
end

// 从IDLE到第一个状态需要一个条件 所以这里增加一个reg
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_idle_cnt <= 'd0;
    else if (r_idle_cnt == 10)
        r_idle_cnt <= 'd0;
    else if (r_st_current == P_ST_IDLE)
        r_idle_cnt <= r_idle_cnt + 1;
    else 
        r_idle_cnt <= r_idle_cnt;
end


// 状态转移需要判断ready是否准备好
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ri_operation_ready <= 'd1;
    else 
        ri_operation_ready <= i_operation_ready;
end

// 第三段 要注意 是脉冲型
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst) begin
        ro_operation_type  <= 'd0;
        ro_operation_addr  <= 'd0;
        ro_operation_num   <= 'd0;
        ro_operation_valid <= 'd0;
    end else if (r_st_current != P_ST_CLEAR && r_st_next == P_ST_CLEAR) begin
        ro_operation_type  <= P_TYPE_WRITE;
        ro_operation_addr  <= 'd0;
        ro_operation_num   <= 'd0;
        ro_operation_valid <= 'd1;
    end else if (r_st_current != P_ST_WRITE && r_st_next == P_ST_WRITE) begin
        ro_operation_type  <= P_TYPE_WRITE;
        ro_operation_addr  <= 'd0;
        ro_operation_num   <= 'd8;
        ro_operation_valid <= 'd1;
    end else if (r_st_current != P_ST_READ && r_st_next == P_ST_READ) begin
        ro_operation_type  <= P_TYPE_READ;
        ro_operation_addr  <= 'd0;
        ro_operation_num   <= 'd8;
        ro_operation_valid <= 'd1;
    end else begin
        ro_operation_type  <= 'd0;
        ro_operation_addr  <= 'd0;
        ro_operation_num   <= 'd0;
        ro_operation_valid <= 'd0;
    end
end


// 控制要写的数据 握手后输出
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_write_valid <= 'd0;
    else if (r_write_cnt == 7)
        ro_write_valid <= 'd0;
    else if (w_operation_active && r_st_current == P_ST_WRITE)
        ro_write_valid <= 'd1;
    else 
        ro_write_valid <= ro_write_valid;
end

// 什么时候valid拉低 以及 eop什么时候拉高 需要计数器
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_write_eop <= 'd0;
    else if (r_write_cnt == 6)
        ro_write_eop <= 'd1;
    else 
        ro_write_eop <= 'd0;
end

// 借助cnt
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_write_cnt <= 'd0;
    else if (r_write_cnt == 7)
        r_write_cnt <= 'd0;
    else if (ro_write_valid)
        r_write_cnt <= r_write_cnt + 1; 
    else 
        r_write_cnt <= r_write_cnt;
end

// sop
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_write_sop <= 'd0;
    else if (w_operation_active && r_st_current == P_ST_WRITE)
        ro_write_sop <= 'd1;
    else 
        ro_write_sop <= 'd0;
end

// 最后是数据
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_write_data <= 'd0;
    else if (w_operation_active && r_st_current == P_ST_WRITE || (ro_write_valid && r_operation_valid_1d) || (ro_write_valid && !r_operation_valid_1d))
        ro_write_data <= ro_write_data + 1;
    else 
        ro_write_data <= ro_write_data;
end

// 给valid打一拍防止输出太多
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_operation_valid_1d <= 'd0;
    else 
        r_operation_valid_1d <= ro_operation_valid;
end

endmodule
