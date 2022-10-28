module EXE_stage(
    input               clk,
    input               reset,
    // allowin
    input               ms_allowin,
    output              es_allowin,
    // input from ID stage
    input               ds_to_es_valid,
    input   [204:0]     ds_to_es_bus,
    // output for MEM stage
    output              es_to_ms_valid,
    output  [212:0]     es_to_ms_bus,
    // data sram interface
    output          data_sram_req,       // if there is a request
    output          data_sram_wr,        // read or write    1 means write and 0 means read
    output  [3:0]   data_sram_wstrb,     // write strobes
    output  [1:0]   data_sram_size,      // number of bytes  0:1 bytes 1:2bytes 2:4bytes
    output  [31:0]  data_sram_addr,      // request addr
    output  [31:0]  data_sram_wdata,     // write data
    input           data_sram_addr_ok,   // if data and addr has been received
    // output es_valid and bus for ID stage
    output              out_es_valid,
    // interrupt signal
    input               wb_ex,
    input               mem_ex,
    input               wb_ertn,
    input               mem_ertn,
    input [63:0]        stable_counter_value
);

wire ale_detected;

wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        gr_we;
wire        res_from_mem;
wire [31:0] pc;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] alu_result_org;
reg [204:0] ds_to_es_bus_r;

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result_org)
    );

reg     es_valid;
wire    es_ready_go;

wire       after_ex;
wire       after_ertn;
assign     after_ertn = mem_ertn | wb_ertn;
assign     after_ex = mem_ex | wb_ex;

// code by JamesYu
// add control signals
wire [6:0] divmul_op;
wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;
wire inst_div_w;
wire inst_mod_w;
wire inst_div_wu;
wire inst_mod_wu;
wire is_mul;
wire is_div;
assign {inst_mul_w,inst_mulh_w,inst_mulh_wu,inst_div_w,inst_mod_w,inst_div_wu,inst_mod_wu} = divmul_op;
assign is_mul = inst_mul_w | inst_mulh_w | inst_mulh_wu;
assign is_div = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu;

// add multiple support
wire [32:0] mul_src1;
wire [32:0] mul_src2;
wire [65:0] signed_result;
wire [31:0] mul_result;
assign mul_src1 = (inst_mulh_w) ? {alu_src1[31],alu_src1} : {1'b0,alu_src1};
assign mul_src2 = (inst_mulh_w) ? {alu_src2[31],alu_src2} : {1'b0,alu_src2};
assign signed_result = $signed(mul_src1) * $signed(mul_src2);
assign mul_result = (inst_mul_w) ? signed_result[31:0] : signed_result[63:32];

// add divison support
wire [31:0] div_result;

//bob add div part
wire div_signed_valid;
wire div_unsigned_valid;
reg div_signed_got;
reg div_unsigned_got;
wire div_signed_ready_divisor;
wire div_signed_ready_dividend;
wire div_unsigned_ready_divisor;
wire div_unsigned_ready_dividend;
wire div_signed_result_valid;
wire div_unsigned_result_valid;
wire [31:0] div_signed_result;
wire [31:0] mod_signed_result;
wire [31:0] div_unsigned_result;
wire [31:0] mod_unsigned_result;

// add st support
wire [31:0] st_data;
wire inst_st_b;
wire inst_st_h;
wire inst_st_w;
wire inst_ld_b;
wire inst_ld_bu;
wire inst_ld_h;
wire inst_ld_hu;
wire inst_ld_w; 
wire [4:0] ld_op;
wire [7:0] ldst_op;

// data sram pre-declare
// code by JamesYu
wire   mem_re;
wire   mem_we;
wire [1:0] addr;
wire [1:0] size;
wire [3:0] wstrb;
wire is_req;
assign is_req = data_sram_req;

assign div_signed_valid = (inst_div_w | inst_mod_w) & ~div_signed_got;
assign div_unsigned_valid = (inst_div_wu | inst_mod_wu) & ~div_unsigned_got;

always @ (posedge clk)
begin
    if(inst_div_w | inst_mod_w)
    begin
        if(div_signed_ready_divisor && div_signed_ready_dividend)
        begin
            div_signed_got <= 1;
        end      
        else if(div_signed_got && div_signed_result_valid)
            div_signed_got <= 0;
    end
    else if(inst_div_wu | inst_mod_wu)
    begin
        if(div_unsigned_ready_divisor && div_unsigned_ready_dividend)
        begin
            div_unsigned_got <= 1;
        end
        else if(div_unsigned_got && div_unsigned_result_valid)
            div_unsigned_got <= 0;
    end
    else
    begin
        div_signed_got <= 0;
        div_unsigned_got <= 0;
    end
end

module_div_signed div_signed(
                    .s_axis_divisor_tdata(alu_src2), 
                    .s_axis_divisor_tready(div_signed_ready_divisor),
                    .s_axis_divisor_tvalid(div_signed_valid),
                    .s_axis_dividend_tdata(alu_src1),
                    .s_axis_dividend_tready(div_signed_ready_dividend),
                    .s_axis_dividend_tvalid(div_signed_valid),
                    .m_axis_dout_tdata({div_signed_result, mod_signed_result}),
                    .m_axis_dout_tvalid(div_signed_result_valid),
                    .aclk(clk)
                 );

module_div_unsigned div_unsigned(
                    .s_axis_divisor_tdata(alu_src2), 
                    .s_axis_divisor_tready(div_unsigned_ready_divisor),
                    .s_axis_divisor_tvalid(div_unsigned_valid),
                    .s_axis_dividend_tdata(alu_src1),
                    .s_axis_dividend_tready(div_unsigned_ready_dividend),
                    .s_axis_dividend_tvalid(div_unsigned_valid),
                    .m_axis_dout_tdata({div_unsigned_result, mod_unsigned_result}),
                    .m_axis_dout_tvalid(div_unsigned_result_valid),
                    .aclk(clk)
                 );

assign div_result = inst_div_w ? div_signed_result :
                    inst_mod_w ? mod_signed_result :
                    inst_div_wu? div_unsigned_result :
                    inst_mod_wu? mod_unsigned_result : 0;
//bob add div part
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if(wb_ex | wb_ertn | ale_detected) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_ready_go    = ((inst_div_w | inst_mod_w) && (~(div_signed_result_valid & div_signed_got))) | ((inst_div_wu | inst_mod_wu) && (~(div_unsigned_result_valid & div_unsigned_got))) ? 1'b0:
                        (mem_re || mem_we) ? data_sram_addr_ok : 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;

// code by JamesYu
// add result select
wire [31:0] write_result;
assign write_result = (is_mul) ? mul_result :
                      (is_div) ? div_result :   alu_result;

// deal with input and output
wire [33:0] csr_data;
wire [2:0]  prev_exception_op;
wire [3:0]  next_exception_op;
wire [31:0] data_sram_addr_error;
wire [2:0] inst_stable_counter;
wire inst_rdcntid;
wire inst_rdcntvh_w;
wire inst_rdcntvl_w;
wire        ds_has_int;
assign next_exception_op = {prev_exception_op,ale_detected};
assign {inst_stable_counter, ds_has_int,prev_exception_op,alu_op,src1_is_pc,pc,rj_value,src2_is_imm,imm,rkd_value,gr_we,dest,res_from_mem,divmul_op,ldst_op,csr_data}=ds_to_es_bus_r;
assign es_to_ms_bus = {is_req,inst_rdcntid,data_sram_addr_error, ds_has_int,next_exception_op,rj_value,rkd_value,csr_data,ld_op,res_from_mem,gr_we,dest,write_result,pc};

assign inst_rdcntid = inst_stable_counter[2];
assign inst_rdcntvh_w = inst_stable_counter[1];
assign inst_rdcntvl_w = inst_stable_counter[0];
wire [31:0] stable_counter_result;
assign stable_counter_result =  inst_rdcntvh_w ? stable_counter_value[63:32] :
                                inst_rdcntvl_w ? stable_counter_value[31:0] : 0;
assign alu_result = (inst_rdcntvh_w | inst_rdcntvl_w) ? stable_counter_result : alu_result_org;

// add support for sd
// code by JamesYu
assign {inst_st_b,inst_st_h,inst_st_w} = ldst_op[2:0];
assign ld_op = ldst_op[7:3];
assign {inst_ld_b,inst_ld_bu,inst_ld_h,inst_ld_hu,inst_ld_w}=ld_op;

assign st_data = inst_st_b ? {4{rkd_value[ 7:0]}} :
                 inst_st_h ? {2{rkd_value[15:0]}} : rkd_value[31:0];

assign ale_detected = ((inst_st_w | inst_ld_w) & (data_sram_addr[1:0] != 2'b00)) ? 1'b1 :
                       ((inst_st_h | inst_ld_h | inst_ld_hu) & (data_sram_addr[0] == 1'b1)) ? 1'b1 : 1'b0;
assign out_es_valid = es_valid;
assign data_sram_addr_error = alu_result;


// deal with data_sram
assign mem_re = inst_ld_b || inst_ld_bu || inst_ld_h || inst_ld_hu || inst_ld_w;
assign mem_we = inst_st_b || inst_st_h || inst_st_w;
assign addr = alu_result[1:0];
assign size = (inst_ld_w | inst_st_w) ? 2'b10 :
              (inst_ld_h | inst_ld_hu | inst_st_h) ? 2'b1 : 2'b0;
assign wstrb = (size==2'b00 && addr==2'b00) ? 4'b0001:
               (size==2'b00 && addr==2'b01) ? 4'b0010:
               (size==2'b00 && addr==2'b10) ? 4'b0100:
               (size==2'b00 && addr==2'b11) ? 4'b1000:
               (size==2'b01 && addr==2'b00) ? 4'b0011:
               (size==2'b01 && addr==2'b10) ? 4'b1100:
               (size==2'b10 && addr==2'b00) ? 4'b1111: 4'b0000;

// data sram interface
assign data_sram_req   = ((mem_re || mem_we) && es_valid && ms_allowin) ? 1'b1 : 1'b0;
assign data_sram_wr    = mem_we? 1'b1 : 1'b0;
assign data_sram_wstrb = (after_ex || after_ertn || ale_detected) ? 4'b0 : wstrb;
assign data_sram_size  = size;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = st_data; 

endmodule