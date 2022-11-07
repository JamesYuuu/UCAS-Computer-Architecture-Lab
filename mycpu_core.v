module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output          inst_sram_req,
    output          inst_sram_wr,
    output [1:0]    inst_sram_size,
    output [3:0]    inst_sram_wstrb,
    output [31:0]   inst_sram_addr,
    output [31:0]   inst_sram_wdata,
    input           inst_sram_addr_ok,
    input           inst_sram_data_ok,
    input [31:0]    inst_sram_rdata,
    // data sram interface
    output          data_sram_req,
    output          data_sram_wr,
    output [1:0]    data_sram_size,
    output [3:0]    data_sram_wstrb,
    output [31:0]   data_sram_addr,
    output [31:0]   data_sram_wdata,
    input           data_sram_addr_ok,
    input           data_sram_data_ok,
    input  [31:0]   data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire         reset;
assign reset = ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [64:0]  fs_to_ds_bus;
wire [208:0] ds_to_es_bus;
wire [213:0] es_to_ms_bus;
wire [206:0] ms_to_ws_bus;
wire [38:0]  rf_bus;
wire [33:0]  br_bus;
wire         out_ms_valid;
wire         out_es_valid;
wire         wb_ex;
wire         mem_ex;
wire         wb_ertn;
wire         mem_ertn;
wire [31:0]  csr_eentry;
wire [31:0]  csr_era;
wire         has_int;
wire [63:0]  stable_counter_value;

// IF stage
IF_stage IF_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin from ID stage
    .ds_allowin     (ds_allowin     ),
    // branch bus
    .br_bus         (br_bus         ),
    // output to ID stage
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),
    // interrupt signal
    .wb_ex          (wb_ex          ),
    .wb_ertn        (wb_ertn        ),
    .csr_era        (csr_era        ),
    .csr_eentry     (csr_eentry     )
);
// ID stage
ID_stage ID_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    // input from IF stage
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // output to EXE stage
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    // branch bus 
    .br_bus         (br_bus         ),
    // rf bus
    .rf_bus         (rf_bus         ),
    // input for hazard
    .out_es_valid   (out_es_valid   ),
    .out_ms_valid   (out_ms_valid   ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .ms_to_ws_valid (ms_to_ws_valid ),
    // interrupt signal
    .wb_ex          (wb_ex          ),
    .wb_ertn        (wb_ertn        ),
    .has_int        (has_int        )
);
// EXE stage
EXE_stage EXE_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    // input from ID stage
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    // output to MEM stage
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_req  (data_sram_req  ),
    .data_sram_wr   (data_sram_wr   ),
    .data_sram_size (data_sram_size ),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    // output es_to_ds_bus to ID stage
    .out_es_valid   (out_es_valid   ),
    // interrupt signal
    .wb_ex          (wb_ex          ),
    .wb_ertn        (wb_ertn        ),
    .mem_ex         (mem_ex         ),
    .mem_ertn       (mem_ertn       ),
    .stable_counter_value(stable_counter_value)
);
// MEM stage
MEM_stage MEM_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    // input from EXE stage
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // output to WB stage
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata),
    // output ms_to_ds_bus for ID stage
    .out_ms_valid   (out_ms_valid   ),
    // interrupt signal
    .wb_ex          (wb_ex          ),
    .wb_ertn        (wb_ertn        ),
    .mem_ertn       (mem_ertn       ),
    .mem_ex         (mem_ex         )
);
// WB stage
WB_stage WB_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin
    .ws_allowin     (ws_allowin     ),
    // input from MEM stage
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // rf_bus
    .rf_bus         (rf_bus         ),
    // trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    // interrupt signal
    .wb_ex          (wb_ex          ),
    .wb_ertn        (wb_ertn        ),
    .csr_era        (csr_era        ),
    .csr_eentry     (csr_eentry     ),
    .has_int        (has_int        ),
    .stable_counter_value(stable_counter_value)
);

endmodule
