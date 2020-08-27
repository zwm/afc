
module tb_top();
// macro
`include "tb_define.v"
// port
reg                         rstn;
reg                         clk;
reg                         afc_cg_auto;
reg                         afc_en;
reg                         trx;
reg         [15:0]          divr;
reg                         rg_forceband_en;
reg         [6:0]           rg_vco_capband;
reg         [1:0]           rg_afc_vcostable_time;
reg         [6:0]           rg_afc_cnt_time;
reg         [14:0]          a2d_afc_ncntr;
reg                         rg_aac_bypass;
reg         [1:0]           rg_aac_stable_time;
reg         [1:0]           rg_aac_cbandrange;
reg         [3:0]           rg_ini_ibsel_rx; // afc_ibvco initial val
reg         [3:0]           rg_ini_ibsel_tx; // afc_ibvco initial val
reg                         a2d_aac_pkd_state;
wire                        afc_openloop_en;
wire        [6:0]           afc_vco_capband;
wire                        afc_cntr_rstn;
wire                        afc_cntr_en;
wire                        afc_cntr_datasyn;
wire        [3:0]           afc_ibvco;
wire        [14:0]          afc_minerr;
wire                        afc_finish;

// main
initial begin
    sys_init;
    #50_000;
    afc_start;

    #1000_000;
    $finish;
end

// inst
afc u_afc (
    .rstn                       ( rstn                          ),
    .clk                        ( clk                           ),
    .afc_cg_auto                ( afc_cg_auto                   ),
    .afc_en                     ( afc_en                        ),
    .trx                        ( trx                           ),
    .divr                       ( divr                          ),
    .rg_forceband_en            ( rg_forceband_en               ),
    .rg_vco_capband             ( rg_vco_capband                ),
    .rg_afc_vcostable_time      ( rg_afc_vcostable_time         ),
    .rg_afc_cnt_time            ( rg_afc_cnt_time               ),
    .a2d_afc_ncntr              ( a2d_afc_ncntr                 ),
    .rg_aac_bypass              ( rg_aac_bypass                 ),
    .rg_aac_stable_time         ( rg_aac_stable_time            ),
    .rg_aac_cbandrange          ( rg_aac_cbandrange             ),
    .rg_ini_ibsel_rx            ( rg_ini_ibsel_rx               ),
    .rg_ini_ibsel_tx            ( rg_ini_ibsel_tx               ),
    .a2d_aac_pkd_state          ( a2d_aac_pkd_state             ),
    .afc_openloop_en            ( afc_openloop_en               ),
    .afc_vco_capband            ( afc_vco_capband               ),
    .afc_cntr_rstn              ( afc_cntr_rstn                 ),
    .afc_cntr_en                ( afc_cntr_en                   ),
    .afc_cntr_datasyn           ( afc_cntr_datasyn              ),
    .afc_ibvco                  ( afc_ibvco                     ),
    .afc_minerr                 ( afc_minerr                    ),
    .afc_finish                 ( afc_finish                    )
);

// fsdb
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
end
`endif

// clk gen
initial begin
    clk = 0;
    rstn = 1;
    fork
        // rstn
        begin
            #50;
            rstn = 0;
            #100;
            rstn = 1;
        end
        // clk
        begin
            #100;
            forever #1 clk = ~clk;
        end
    join
end

// sys_init
task sys_init;
    begin
        afc_cg_auto             = 1;
        afc_en                  = 0;
        trx                     = 0;
        divr                    = 64;
        rg_forceband_en         = 0;
        rg_vco_capband          = 0;
        rg_afc_vcostable_time   = 2;
        rg_afc_cnt_time         = 128;
        a2d_afc_ncntr           = 99;
        rg_aac_bypass           = 1;
        rg_aac_stable_time      = 0;
        rg_aac_cbandrange       = 0;
        rg_ini_ibsel_rx         = 0;
        rg_ini_ibsel_tx         = 0;
        a2d_aac_pkd_state       = 0;
    end
endtask

task afc_start;
    begin
        @(posedge clk);
        afc_en = 1;
        repeat(10) @(posedge clk);
        afc_en = 0;
    end
endtask

endmodule

