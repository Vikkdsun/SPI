// 这是一个SPI串口发送工程(模式0)
/*
    输入数据和valid同步
    通过valid和ready握手 控制 cs， 控制 run， 
    通过cs控制分频时钟，
    通过run控制cnt
    通过cnt控制传输的数据
*/

module spi_drive#(
    parameter                           P_DATA_WIDTH        = 8                 ,    
    parameter                           P_CPOL              = 0                 ,   
    parameter                           P_CPHL              = 0                 ,  
    parameter                           P_READ_DATA_WIDTH   = 8                 ,
)(
    input                               i_clk                               ,
    input                               i_rst                               ,
    
    output                              o_spi_clk                           ,
    output                              o_spi_cs                            ,
    output                              o_spi_mosi                          ,
    input                               i_spi_miso                          ,

    input   [P_DATA_WIDTH - 1:0]        i_user_data                         ,
    input                               i_user_valid                        ,
    output                              o_user_ready                        ,

    output  [P_READ_DATA_WIDTH - 1:0]   o_user_read_data                    ,
    output                              o_user_read_valid                   
);

// 常规操作 对output寄存
(* mark_debug = "true" *)reg                                             ro_spi_mosi                                             ;          // debug
(* mark_debug = "true" *)reg                                             ro_spi_clk                                              ;
(* mark_debug = "true" *)reg                                             ro_spi_cs                                               ;
reg                                             ro_user_ready                                           ;
reg                 [P_READ_DATA_WIDTH - 1:0]   ro_user_read_data                                       ;           // 在top加了debug
reg                                             ro_user_read_valid                                      ;

reg                                             r_run                                                   ;
reg                                             r_run_1d                                                ;

// 常规cnt
reg [15:0]                                      r_cnt                                                   ;
// 取数cnt
reg                                             r_spi_cnt                                               ;

assign                                          o_spi_clk     =   ro_spi_clk                            ;
assign                                          o_spi_cs      =   ro_spi_cs                             ;
assign                                          o_spi_mosi    =   ro_spi_mosi                           ;
assign                                          o_user_ready  =   ro_user_ready                         ;
assign                                          o_user_read_data  = ro_user_read_data                   ;
assign                                          o_user_read_valid = ro_user_read_valid                  ;

// 首先做握手   
wire                                            w_user_active                                           ;
assign                                          w_user_active =   i_user_valid & o_user_ready           ;

// 对输入数据做一个寄存器   
reg [P_DATA_WIDTH - 1:0]                        r_user_data                                             ;

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_user_data <= 'd0;
    else if (w_user_active)
        r_user_data <= i_user_data << 1 ;
    else
        r_user_data <= r_user_data;
end

// 控制run
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_run <= 'd0;
    else if (r_cnt == 'd7 && r_spi_cnt == 'd1)
        r_run <= 'd0;
    else if (w_user_active)
        r_run <= 'd1;
    else 
        r_run <= r_run;
end

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_run_1d <= 'd0;
    else 
        r_run_1d <= r_run;
end


// 计数器
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_cnt <= 'd0;
    else if (r_spi_cnt)
        if (r_cnt == 'd7)
            r_cnt <= 'd0;
        else
            r_cnt <= r_cnt + 1;
    else 
        r_cnt <= r_cnt;
end

always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        r_spi_cnt <= 'd0;
    else if (r_run)
        if (r_spi_cnt == 1)
            r_spi_cnt <= 'd0;
        else
            r_spi_cnt <= r_spi_cnt + 1;
    else 
        r_cnt <= r_cnt;
end

// spi时钟
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_spi_clk <= P_CPOL;          // 模式0
    else if (r_run)
        ro_spi_clk <= ~ro_spi_clk;
    else 
        ro_spi_clk <= P_CPOL;
end

// cs
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_spi_cs <= 'd1;
    else if (w_user_active)             // 优先级更高 放在前面 否则cs出错
        ro_spi_cs <= 'd0;
    else if (!r_run)
        ro_spi_cs <= 'd1;
    else 
        ro_spi_cs <= ro_spi_cs;
end

// mosi
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_spi_mosi <= 'd0;
    else if (w_user_active)
        ro_spi_mosi <= i_user_data[P_DATA_WIDTH - 1];
    else if (r_spi_cnt)
        ro_spi_mosi <= r_user_data[P_DATA_WIDTH - 1];
    else 
        ro_spi_mosi <= ro_spi_mosi;
end

// miso和有效信号
always@(posedge ro_spi_clk or posedge i_rst)            // 注意时钟
begin
    if (i_rst)
        ro_user_read_data <= 'd0;
    else
        ro_user_read_data <= {ro_user_read_data[P_READ_DATA_WIDTH - 2:0], i_spi_miso};
        
end

always@(posedge i_clk or posedge i_rst)            
begin
    if (i_rst)
        ro_user_read_valid <= 'd0;
    else if (r_cnt == 'd7 && r_spi_cnt == 'd1)
        ro_user_read_valid <= 'd1;
    else 
        ro_user_read_valid <= 'd0;
end

// ready
always@(posedge i_clk or posedge i_rst)
begin
    if (i_rst)
        ro_user_ready <= 'd0;
    else if (!r_run && r_run_1d)
        ro_user_ready <= 'd0;
    else if (w_user_active)
        ro_user_ready <= 'd1;
    else 
        ro_user_ready <= ro_user_ready;
end

endmodule

