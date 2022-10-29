module csr(
    input              reset,
    input              clk,
    input              csr_re,
    input   [13:0]     csr_num,
    output  [31:0]     csr_rvalue,
    output  [31:0]     csr_eentry,
    input              csr_we,
    input   [31:0]     csr_wmask,
    input   [31:0]     csr_wvalue,
    input   [5:0]      wb_ecode,
    input   [8:0]      wb_esubcode,
    input              wb_ex,
    input   [31:0]     wb_pc,
    input   [31:0]     wb_vaddr,
    input   [31:0]     coreid_in,
    input              ertn_flush,
    input   [7:0]      hw_int_in,
    output             has_int,
    output  [63:0]     stable_counter_value,
    input              ipi_int_in
);

// translate csr_num to csr;
wire  is_csr_crmd;
wire  is_csr_prmd;
wire  is_csr_ecfg;
wire  is_csr_estat;
wire  is_csr_era;
wire  is_csr_badv;
wire  is_csr_eentry;
wire  is_csr_save0;
wire  is_csr_save1;
wire  is_csr_save2;
wire  is_csr_save3;
wire  is_csr_llbctl; 
wire  is_csr_tid;
wire  is_csr_tcfg;
wire  is_csr_tval;
wire  is_csr_ticlr;

assign is_csr_crmd   = (csr_num == 14'h0);
assign is_csr_prmd   = (csr_num == 14'h1);
assign is_csr_ecfg   = (csr_num == 14'h4);
assign is_csr_estat  = (csr_num == 14'h5);
assign is_csr_era    = (csr_num == 14'h6);
assign is_csr_badv   = (csr_num == 14'h7);
assign is_csr_eentry = (csr_num == 14'hc);
assign is_csr_save0  = (csr_num == 14'h30);
assign is_csr_save1  = (csr_num == 14'h31);
assign is_csr_save2  = (csr_num == 14'h32);
assign is_csr_save3  = (csr_num == 14'h33);
assign is_csr_llbctl = (csr_num == 14'h60);
assign is_csr_tid    = (csr_num == 14'h40);
assign is_csr_tcfg   = (csr_num == 14'h41);
assign is_csr_tval   = (csr_num == 14'h42);
assign is_csr_ticlr  = (csr_num == 14'h44);

// translate ecode and esubcode;
wire  is_adef;
wire  is_ale;
wire  is_brk;
wire  is_ine;

assign is_adef = (wb_ecode == 6'h8 && wb_esubcode == 9'h0);
assign is_ale  = (wb_ecode == 6'h9);
assign is_brk  = (wb_ecode == 6'hc);
assign is_ine  = (wb_ecode == 6'hd);

// note that csr_{reg_name}_reserve is read-only and always return 0;
// note that we don't consider some domains in csr_crmd and csr_prmd;

// basic csr_regs;
// csr_crmd;
reg  [1:0]   csr_crmd_plv;
reg          csr_crmd_ie;
reg          csr_crmd_da;
reg          csr_crmd_pg;
reg  [1:0]   csr_crmd_datf;
reg  [1:0]   csr_crmd_datm;
wire [31:0]  csr_crmd;
// assign csr_crmd = {23'b0 , csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
assign csr_crmd = {28'b0,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};

// csr_prmd;
reg  [1:0]   csr_prmd_pplv;
reg          csr_prmd_pie;
wire [31:0]  csr_prmd;
// assign csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};
assign csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};

// csr_ecfg;
reg  [12:0]  csr_ecfg_lie;        // note that csr_ecfg_lie[10] is always zero;
wire [31:0]  csr_ecfg;
assign csr_ecfg = {19'b0, csr_ecfg_lie};

// csr_estat; 
reg  [12:0]  csr_estat_is;
reg  [5:0]   csr_estat_ecode;
reg  [8:0]   csr_estat_esubcode;
wire [31:0]  csr_estat;
assign csr_estat = {1'b0,csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is[12:11], 1'b0, csr_estat_is[9:0]};

// csr_era;
reg  [31:0]  csr_era;

// csr_badv;
reg  [31:0]  csr_badv;

// csr_eentry;
reg  [25:0]  csr_eentry_va;
assign csr_eentry = {csr_eentry_va, 6'b0};

// csr_save0_3;
reg  [31:0]  csr_save0;
reg  [31:0]  csr_save1;
reg  [31:0]  csr_save2;
reg  [31:0]  csr_save3;

// csr_llbctl; 
reg          csr_llbctl_rollb;  // read-only ;
reg          csr_llbctl_wcllb;  // write-1-only ; ignore write-0 ;
reg  [1:0]   csr_llbctl_klo;
wire [31:0]  csr_llbctl;
assign csr_llbctl = {28'b0, csr_llbctl_klo, csr_llbctl_wcllb, csr_llbctl_rollb};

// csr_regs for timer;
// csr_tid;
reg  [31:0]  csr_tid;

// csr_tcfg;
reg          csr_tcfg_en;
reg          csr_tcfg_periodic;
reg  [29:0]  csr_tcfg_initval;
wire [31:0]  csr_tcfg;
assign csr_tcfg = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

// csr_tval;
wire  [31:0]  csr_tval;
wire  [31:0]  tcfg_next_value;
reg   [31:0]  timer_cnt;

// csr_ticlr;
wire         csr_ticlr_clr;   // write-1-only ; ignore write-0 ;
wire [31:0]  csr_ticlr;
assign csr_ticlr = {31'b0, csr_ticlr_clr};

// control csr_crmd_plv and csr_crmd_ie and csr_crmd_da;
always @(posedge clk) begin
    if (reset)  begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if (wb_ex) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if (ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie <= csr_prmd_pie;
    end
    else if (csr_we && is_csr_crmd) begin
        csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0]
                     | ~csr_wmask[1:0] & csr_crmd_plv;
        csr_crmd_ie  <= csr_wmask[2] & csr_wvalue[2]
                     | ~csr_wmask[2] & csr_crmd_ie;
    end

    csr_crmd_da <= 1'b1;
end

// control csr_prmd_pplv and csr_prmd_pie;
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && is_csr_prmd) begin
        csr_prmd_pplv <= csr_wmask[1:0] & csr_wvalue[1:0]
                      | ~csr_wmask[1:0] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[2] & csr_wvalue[2]
                      | ~csr_wmask[2] & csr_prmd_pie;
    end
end

// control csr_ecfg_lie;
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && is_csr_ecfg)
        csr_ecfg_lie <= csr_wmask[12:0] & csr_wvalue[12:0]
                     | ~csr_wmask[12:0] & csr_ecfg_lie;
end

// control csr_estat_is;
always @(posedge clk) begin
    // software interrupt
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && is_csr_estat)
        csr_estat_is[1:0] <= csr_wmask[1:0] & csr_wvalue[1:0]
                          | ~csr_wmask[1:0] & csr_estat_is[1:0];

    // hardware interrupt
    csr_estat_is[9:2] <= hw_int_in[7:0];

    // reserve
    csr_estat_is[10]  <= 1'b0;

    // timer interrupt
    if (timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && is_csr_ticlr && csr_wmask[0] && csr_wvalue[0])
        csr_estat_is[11] <= 1'b0;
    
    // note that we don't consider Inter-Processor Interrupt here;
    csr_estat_is[12] <= ipi_int_in;
end

// control csr_estat_ecode and csr_estat_esubcode;
always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end 
end

// control csr_era;
always @(posedge clk) begin
    if (wb_ex)
        csr_era <= wb_pc;
    else if (csr_we && is_csr_era)
        csr_era <= csr_wmask[31:0] & csr_wvalue[31:0]
                | ~csr_wmask[31:0] & csr_era;
end

// control csr_badv_vaddr
assign wb_ex_addr_err = is_adef || is_ale;
always @(posedge clk) begin
    if (wb_ex_addr_err && wb_ex)
        csr_badv <= is_adef ? wb_pc : wb_vaddr;
end

// control csr_eentry_va;
always @(posedge clk) begin
    if (csr_we && is_csr_eentry)
        csr_eentry_va <= csr_wmask[31:6] & csr_wvalue[31:6]
                      | ~csr_wmask[31:6] & csr_eentry_va;
end

// control csr_save0_3;
always @(posedge clk) begin
    if (csr_we && is_csr_save0)
        csr_save0 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save0;
    if (csr_we && is_csr_save1)
        csr_save1 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save1;
    if (csr_we && is_csr_save2)
        csr_save2 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save2;
    if (csr_we && is_csr_save3)
        csr_save3 <= csr_wmask[31:0] & csr_wvalue[31:0]
                  | ~csr_wmask[31:0] & csr_save3;
end

// control csr_tid
always @(posedge clk) begin
    if (reset)
        csr_tid = coreid_in;
    else if (csr_we && is_csr_tid)
        csr_tid <= csr_wmask[31:0] & csr_wvalue[31:0]
                | ~csr_wmask[31:0] & csr_tid;
end

// control csr_tcfg_en and csr_tcfg_periodic and csr_tcfg_initval;
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && is_csr_tcfg)
        csr_tcfg_en <= csr_wmask[0] & csr_wvalue[0]
                    | ~csr_wmask[0] & csr_tcfg_en;

    if (csr_we && is_csr_tcfg) begin
        csr_tcfg_periodic <= csr_wmask[1] & csr_wvalue[1]
                          | ~csr_wmask[1] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[31:2] & csr_wvalue[31:2]
                         | ~csr_wmask[31:2] & csr_tcfg_initval;
    end
end

// control csr_tval_timeval
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                      | ~csr_wmask[31:0] & csr_tcfg;

always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && is_csr_tcfg && tcfg_next_value[0])
        timer_cnt <= {tcfg_next_value[31:2],2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval[29:0],2'b0};
        else 
            timer_cnt <= timer_cnt - 1'b1;
    end
end

assign csr_tval = timer_cnt;

reg [63:0] stable_counter_r;
assign stable_counter_value = stable_counter_r;

always @(posedge clk) begin
    if(reset)
        stable_counter_r <= 64'b0;
    else
        stable_counter_r <= stable_counter_r + 1;
end

// control csr_ticlr_clr
assign csr_ticlr_clr = 1'b0;

assign csr_rvalue = (({32{is_csr_crmd}} & csr_crmd)
                  | ({32{is_csr_prmd}} & csr_prmd)
                  | ({32{is_csr_ecfg}} & csr_ecfg)
                  | ({32{is_csr_estat}} & csr_estat)
                  | ({32{is_csr_era}} & csr_era)
                  | ({32{is_csr_badv}} & csr_badv)
                  | ({32{is_csr_eentry}} & csr_eentry)
                  | ({32{is_csr_save0}} & csr_save0)
                  | ({32{is_csr_save1}} & csr_save1)
                  | ({32{is_csr_save2}} & csr_save2)
                  | ({32{is_csr_save3}} & csr_save3)
                  | ({32{is_csr_llbctl}} & csr_llbctl)
                  | ({32{is_csr_tid}} & csr_tid)
                  | ({32{is_csr_tcfg}} & csr_tcfg)
                  | ({32{is_csr_tval}} & csr_tval)
                  | ({32{is_csr_ticlr}} & csr_ticlr)) & {32{csr_re}};

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);

endmodule