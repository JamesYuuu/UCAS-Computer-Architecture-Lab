module mycpu_core#(
    parameter TLBNUM = 16
)
(
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
wire [68:0]  fs_to_ds_bus;
wire [218:0] ds_to_es_bus;
wire [230:0] es_to_ms_bus;
wire [223:0] ms_to_ws_bus;
wire [38:0]  rf_bus;
wire [33:0]  br_bus;
wire         out_ms_valid;
wire         out_es_valid;
wire         wb_ex;
wire         mem_ex;
wire         wb_ertn;
wire         mem_ertn;
wire [31:0]  eentry;
wire [31:0]  csr_era;
wire         has_int;
wire [63:0]  stable_counter_value;

wire         mem_write_asid_ehi;
wire         wb_write_asid_ehi;
wire         csr_critical_change;

wire         wb_refetch;
wire         mem_refetch;
wire [31:0]  refetch_pc;

wire [31:0]  csr_asid;
wire [31:0]  csr_tlbehi;

// tlb
wire  [18:0]                 s0_vppn;
wire                         s0_va_bit12;
wire  [9:0]                  s0_asid;
wire                         s0_found;
wire  [$clog2(TLBNUM)-1:0]   s0_index;
wire  [19:0]                 s0_ppn;
wire  [5:0]                  s0_ps;
wire  [1:0]                  s0_plv;
wire  [1:0]                  s0_mat;
wire                         s0_d;
wire                         s0_v;
// search port 1 (for load/store)
wire  [18:0]                 s1_vppn;
wire                         s1_va_bit12;
wire  [9:0]                  s1_asid;
wire                         s1_found;
wire  [$clog2(TLBNUM)-1:0]   s1_index;
wire  [19:0]                 s1_ppn;
wire  [5:0]                  s1_ps;
wire  [1:0]                  s1_plv;
wire  [1:0]                  s1_mat;
wire                         s1_d;
wire                         s1_v;
// invalid tlb opcode
wire                         invtlb_valid;
wire  [4:0]                  invtlb_op;
// write port
wire                         we;
wire  [$clog2(TLBNUM)-1:0]   w_index;
wire                         w_e;
wire  [18:0]                 w_vppn;
wire  [5:0]                  w_ps;
wire  [9:0]                  w_asid;
wire                         w_g;
wire  [19:0]                 w_ppn0;
wire  [1:0]                  w_plv0;
wire  [1:0]                  w_mat0;
wire                         w_d0;
wire                         w_v0;
wire  [19:0]                 w_ppn1;
wire  [1:0]                  w_plv1;
wire  [1:0]                  w_mat1;
wire                         w_d1;
wire                         w_v1;
// read port
wire  [$clog2(TLBNUM)-1:0]   r_index;
wire                         r_e;
wire  [18:0]                 r_vppn;
wire  [5:0]                  r_ps;
wire  [9:0]                  r_asid;
wire                         r_g;
wire  [19:0]                 r_ppn0;
wire  [1:0]                  r_plv0;
wire  [1:0]                  r_mat0;
wire                         r_d0;
wire                         r_v0;
wire  [19:0]                 r_ppn1;
wire  [1:0]                  r_plv1;
wire  [1:0]                  r_mat1;
wire                         r_d1;
wire                         r_v1;

wire                         ex_inst_tlb_srch;

// to do address translation
wire    [31:0]              csr_dmw0;
wire    [31:0]              csr_dmw1;
wire    [31:0]              csr_crmd;

// IF stage
IF_stage IF_stage(
    .clk                    (clk                    ),
    .reset                  (reset                  ),
    // allowin from ID stage        
    .ds_allowin             (ds_allowin             ),
    // branch bus       
    .br_bus                 (br_bus                 ),
    // output to ID stage       
    .fs_to_ds_valid         (fs_to_ds_valid         ),
    .fs_to_ds_bus           (fs_to_ds_bus           ),
    // inst sram interface      
    .inst_sram_req          (inst_sram_req          ),
    .inst_sram_wr           (inst_sram_wr           ),
    .inst_sram_size         (inst_sram_size         ),
    .inst_sram_wstrb        (inst_sram_wstrb        ),
    .inst_sram_addr         (inst_sram_addr         ),
    .inst_sram_wdata        (inst_sram_wdata        ),
    .inst_sram_addr_ok      (inst_sram_addr_ok      ),
    .inst_sram_data_ok      (inst_sram_data_ok      ),
    .inst_sram_rdata        (inst_sram_rdata        ),
    // interrupt signal 
    .wb_ex                  (wb_ex                  ),
    .wb_ertn                (wb_ertn                ),
    .csr_era                (csr_era                ),
    .eentry                 (eentry                 ),
    .csr_critical_change    (csr_critical_change    ),
    .wb_refetch             (wb_refetch             ),
    .refetch_pc             (refetch_pc             ),
    // csr
    .csr_dmw0               (csr_dmw0               ),
    .csr_dmw1               (csr_dmw1               ),
    .csr_crmd               (csr_crmd               ),
    .csr_asid               (csr_asid               ),
    // search port 0 (for fetch)   
    .s0_vppn                (s0_vppn                ),
    .s0_va_bit12            (s0_va_bit12            ),
    .s0_asid                (s0_asid                ),
    .s0_found               (s0_found               ),
    .s0_index               (s0_index               ),
    .s0_ppn                 (s0_ppn                 ),  
    .s0_ps                  (s0_ps                  ),
    .s0_plv                 (s0_plv                 ),
    .s0_mat                 (s0_mat                 ),
    .s0_d                   (s0_d                   ),
    .s0_v                   (s0_v                   )
);  
// ID stage 
ID_stage ID_stage(  
    .clk                    (clk                    ),
    .reset                  (reset                  ),
    // allowin
    .es_allowin             (es_allowin             ),
    .ds_allowin             (ds_allowin             ),
    // input from IF stage  
    .fs_to_ds_valid         (fs_to_ds_valid         ),
    .fs_to_ds_bus           (fs_to_ds_bus           ),
    // output to EXE stage  
    .ds_to_es_valid         (ds_to_es_valid         ),
    .ds_to_es_bus           (ds_to_es_bus           ),
    // branch bus   
    .br_bus                 (br_bus                 ),
    // rf bus       
    .rf_bus                 (rf_bus                 ),
    // input for hazard     
    .out_es_valid           (out_es_valid           ),
    .out_ms_valid           (out_ms_valid           ),
    .ms_to_ws_bus           (ms_to_ws_bus           ),
    .es_to_ms_bus           (es_to_ms_bus           ),
    .ms_to_ws_valid         (ms_to_ws_valid         ),
    // interrupt signal     
    .wb_ex                  (wb_ex                  ),
    .wb_ertn                (wb_ertn                ),
    .has_int                (has_int                ),
    .csr_critical_change    (csr_critical_change    ),
    .wb_refetch             (wb_refetch             )
);  
// EXE stage    
EXE_stage EXE_stage(    
    .clk                    (clk                    ),
    .reset                  (reset                  ),
    // allowin              
    .ms_allowin             (ms_allowin             ),
    .es_allowin             (es_allowin             ),
    // input from ID stage      
    .ds_to_es_valid         (ds_to_es_valid         ),
    .ds_to_es_bus           (ds_to_es_bus           ),
    // output to MEM stage      
    .es_to_ms_valid         (es_to_ms_valid         ),
    .es_to_ms_bus           (es_to_ms_bus           ),
    // data sram interface  
    .data_sram_req          (data_sram_req          ),
    .data_sram_wr           (data_sram_wr           ),
    .data_sram_size         (data_sram_size         ),
    .data_sram_wstrb        (data_sram_wstrb        ),
    .data_sram_addr         (data_sram_addr         ),
    .data_sram_wdata        (data_sram_wdata        ),
    .data_sram_addr_ok      (data_sram_addr_ok      ),
    // output es_to_ds_bus to ID stage  
    .out_es_valid           (out_es_valid           ),
    // interrupt signal
    .wb_ex                  (wb_ex                  ),
    .wb_ertn                (wb_ertn                ),
    .mem_ex                 (mem_ex                 ),
    .mem_ertn               (mem_ertn               ),
    .stable_counter_value   (stable_counter_value   ),
    // tlb
    .invtlb_valid           (invtlb_valid           ),
    .ex_inst_tlb_srch       (ex_inst_tlb_srch       ),
    .invtlb_op              (invtlb_op              ),
    .mem_write_asid_ehi     (mem_write_asid_ehi     ),
    .wb_write_asid_ehi      (wb_write_asid_ehi      ),
    .wb_refetch             (wb_refetch             ),
    .mem_refetch            (mem_refetch            ),
    // csr
    .csr_asid               (csr_asid               ),
    .csr_tlbehi             (csr_tlbehi             ),
    .csr_dmw0               (csr_dmw0               ),
    .csr_dmw1               (csr_dmw1               ),
    .csr_crmd               (csr_crmd               ),
    // search port 1 (for load/store) 
    .s1_vppn                (s1_vppn                ),
    .s1_va_bit12            (s1_va_bit12            ),
    .s1_asid                (s1_asid                ),
    .s1_found               (s1_found               ),
    .s1_index               (s1_index               ),
    .s1_ppn                 (s1_ppn                 ),
    .s1_ps                  (s1_ps                  ),
    .s1_plv                 (s1_plv                 ),
    .s1_mat                 (s1_mat                 ),
    .s1_d                   (s1_d                   ),
    .s1_v                   (s1_v                   )
);
// MEM stage
MEM_stage MEM_stage(
    .clk                    (clk                    ),
    .reset                  (reset                  ),
    // allowin      
    .ws_allowin             (ws_allowin             ),
    .ms_allowin             (ms_allowin             ),
    // input from EXE stage     
    .es_to_ms_valid         (es_to_ms_valid         ),
    .es_to_ms_bus           (es_to_ms_bus           ),
    // output to WB stage       
    .ms_to_ws_valid         (ms_to_ws_valid         ),
    .ms_to_ws_bus           (ms_to_ws_bus           ),
    //from data-sram        
    .data_sram_data_ok      (data_sram_data_ok      ),
    .data_sram_rdata        (data_sram_rdata        ),
    // output ms_to_ds_bus for ID stage
    .out_ms_valid           (out_ms_valid           ),
    // interrupt signal
    .wb_ex                  (wb_ex                  ),
    .wb_ertn                (wb_ertn                ),
    .mem_ertn               (mem_ertn               ),
    .mem_ex                 (mem_ex                 ),
    .mem_write_asid_ehi     (mem_write_asid_ehi     ),
    .wb_write_asid_ehi      (wb_write_asid_ehi      ),
    .mem_refetch            (mem_refetch            ),
    .wb_refetch             (wb_refetch             )
);
// WB stage
WB_stage WB_stage(
    .clk                    (clk                    ),
    .reset                  (reset                  ),
    // allowin
    .ws_allowin             (ws_allowin             ),
    // input from MEM stage
    .ms_to_ws_valid         (ms_to_ws_valid         ),
    .ms_to_ws_bus           (ms_to_ws_bus           ),
    // rf_bus
    .rf_bus                 (rf_bus                 ),
    // trace debug interface
    .debug_wb_pc            (debug_wb_pc            ),
    .debug_wb_rf_we         (debug_wb_rf_we         ),
    .debug_wb_rf_wnum       (debug_wb_rf_wnum       ),
    .debug_wb_rf_wdata      (debug_wb_rf_wdata      ),
    // interrupt signal
    .wb_ex                  (wb_ex                  ),
    .wb_ertn                (wb_ertn                ),
    .csr_era                (csr_era                ),
    .eentry                 (eentry                 ),
    .has_int                (has_int                ),
    .stable_counter_value   (stable_counter_value   ),
    .ex_inst_tlb_srch       (ex_inst_tlb_srch       ),
    // csr
    // write port
    .we                     (we                     ),
    .w_index                (w_index                ),
    .w_e                    (w_e                    ),
    .w_ps                   (w_ps                   ),
    .w_vppn                 (w_vppn                 ),
    .w_asid                 (w_asid                 ),
    .w_g                    (w_g                    ),
    .w_ppn0                 (w_ppn0                 ),
    .w_plv0                 (w_plv0                 ),
    .w_mat0                 (w_mat0                 ),
    .w_d0                   (w_d0                   ),
    .w_v0                   (w_v0                   ),
    .w_ppn1                 (w_ppn1                 ),
    .w_plv1                 (w_plv1                 ),
    .w_mat1                 (w_mat1                 ),
    .w_d1                   (w_d1                   ),
    .w_v1                   (w_v1                   ),
    // read port        
    .r_index                (r_index                ),
    .r_e                    (r_e                    ),
    .r_vppn                 (r_vppn                 ),
    .r_ps                   (r_ps                   ),
    .r_asid                 (r_asid                 ),
    .r_g                    (r_g                    ),
    .r_ppn0                 (r_ppn0                 ),
    .r_plv0                 (r_plv0                 ),
    .r_mat0                 (r_mat0                 ),
    .r_d0                   (r_d0                   ),
    .r_v0                   (r_v0                   ),
    .r_ppn1                 (r_ppn1                 ),     
    .r_plv1                 (r_plv1                 ),
    .r_mat1                 (r_mat1                 ),
    .r_d1                   (r_d1                   ),
    .r_v1                   (r_v1                   ),
    .s1_found               (s1_found               ),
    .s1_index               (s1_index               ),
    .wb_write_asid_ehi      (wb_write_asid_ehi      ),
    .wb_refetch             (wb_refetch             ),
    .refetch_pc             (refetch_pc             ),
    .csr_asid               (csr_asid               ),
    .csr_tlbehi             (csr_tlbehi             ),
    .csr_dmw0               (csr_dmw0               ),
    .csr_dmw1               (csr_dmw1               ),
    .csr_crmd               (csr_crmd               )
);      
// tlb      
tlb tlb(        
    .clk                    (clk                    ),
    // search port 0 (for fetch)        
    .s0_vppn                (s0_vppn                ),
    .s0_va_bit12            (s0_va_bit12            ),
    .s0_asid                (s0_asid                ),
    .s0_found               (s0_found               ),
    .s0_index               (s0_index               ),
    .s0_ppn                 (s0_ppn                 ),  
    .s0_ps                  (s0_ps                  ),
    .s0_plv                 (s0_plv                 ),
    .s0_mat                 (s0_mat                 ),
    .s0_d                   (s0_d                   ),
    .s0_v                   (s0_v                   ),
    // search port 1 (for load/store)       
    .s1_vppn                (s1_vppn                ),
    .s1_va_bit12            (s1_va_bit12            ),
    .s1_asid                (s1_asid                ),
    .s1_found               (s1_found               ),
    .s1_index               (s1_index               ),
    .s1_ppn                 (s1_ppn                 ),
    .s1_ps                  (s1_ps                  ),
    .s1_plv                 (s1_plv                 ),
    .s1_mat                 (s1_mat                 ),
    .s1_d                   (s1_d                   ),
    .s1_v                   (s1_v                   ),
    // invtlb opcode        
    .invtlb_op              (invtlb_op              ),
    .invtlb_valid           (invtlb_valid           ),
    // write port       
    .we                     (we                     ),
    .w_index                (w_index                ),
    .w_e                    (w_e                    ),
    .w_ps                   (w_ps                   ),
    .w_vppn                 (w_vppn                 ),
    .w_asid                 (w_asid                 ),
    .w_g                    (w_g                    ),
    .w_ppn0                 (w_ppn0                 ),
    .w_plv0                 (w_plv0                 ),
    .w_mat0                 (w_mat0                 ),
    .w_d0                   (w_d0                   ),
    .w_v0                   (w_v0                   ),
    .w_ppn1                 (w_ppn1                 ),
    .w_plv1                 (w_plv1                 ),
    .w_mat1                 (w_mat1                 ),
    .w_d1                   (w_d1                   ),
    .w_v1                   (w_v1                   ),
    // read port        
    .r_index                (r_index                ),
    .r_e                    (r_e                    ),
    .r_vppn                 (r_vppn                 ),
    .r_ps                   (r_ps                   ),
    .r_asid                 (r_asid                 ),
    .r_g                    (r_g                    ),
    .r_ppn0                 (r_ppn0                 ),
    .r_plv0                 (r_plv0                 ),
    .r_mat0                 (r_mat0                 ),
    .r_d0                   (r_d0                   ),
    .r_v0                   (r_v0                   ),
    .r_ppn1                 (r_ppn1                 ),     
    .r_plv1                 (r_plv1                 ),
    .r_mat1                 (r_mat1                 ),
    .r_d1                   (r_d1                   ),
    .r_v1                   (r_v1                   )
);      

endmodule
