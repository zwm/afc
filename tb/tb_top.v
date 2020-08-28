
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
reg         [13:0]          a2d_afc_ncntr;
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
wire        [13:0]          afc_minerr;
wire                        afc_finish;
// global
integer err_cnt, chk_cnt, case_num;
reg [48*8-1:0] log_dir;
reg         [6:0]           target_vco_capband;
reg [13:0] ncntr_table [255:0];

// main
initial begin
    sys_init;
    #1_000;

    // start sim
    main_loop;

    // disp
    #1_000;
    disp_sum;

    #1_000;
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

// ncntr logic
wire [7:0] ncntr_index = {trx, afc_vco_capband};
always @(posedge clk or negedge rstn)
    if (~rstn)
        a2d_afc_ncntr <= {$random}%(2**14);
    else if (~afc_cntr_rstn)
        a2d_afc_ncntr <= {$random}%(2**14);
    else if (afc_cntr_datasyn)
        a2d_afc_ncntr <= ncntr_table[ncntr_index];
// fsdb
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
    $fsdbDumpMDA();
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
        case_num                = 0;
        chk_cnt                 = 0;
        err_cnt                 = 0;
        afc_cg_auto             = 0;
        afc_en                  = 0;
        trx                     = 0;
        divr                    = 0;
        rg_forceband_en         = 0;
        rg_vco_capband          = 0;
        rg_afc_vcostable_time   = 0;
        rg_afc_cnt_time         = 0;
        a2d_afc_ncntr           = 0;
        rg_aac_bypass           = 0;
        rg_aac_stable_time      = 0;
        rg_aac_cbandrange       = 0;
        rg_ini_ibsel_rx         = 0;
        rg_ini_ibsel_tx         = 0;
        a2d_aac_pkd_state       = 0;
    end
endtask

task main_loop;
    integer fp, ret, i, j, k, tmp;
    begin
        // openfile
        fp = $fopen(`FILE_CASE_LIST, "r");
        // case loop
        begin: CASE_LOOP
            while(1) begin
                ret = $fscanf(fp, "%s", log_dir);
                if (ret != 1) begin
                    $display("%t, CASE_LIST FILE: %s, read end, simulation finish!", $time, `FILE_CASE_LIST);
                    disable CASE_LOOP;
                end
                //$display("%t, CASE_LIST FILE: %s, ret: %d, log_dir: %s", $time, `FILE_CASE_LIST, ret, log_dir);
                // load_cfg
                load_cfg;
                load_ncntr;
                afc_start;
                repeat(10) @(posedge clk);
                fork
                    afc_check;
                    ndec_check;
                join
                #200;
                case_num = case_num + 1;
            end
        end
        // close file
        $fclose(fp);
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

task load_cfg;
    integer fp, ret, i, j, k, tmp;
    reg [32*8-1:0] str;
    begin
        fp = $fopen({log_dir, "/", `FILE_CFG}, "r");
        ret = $fscanf(fp, "%s %d", str, target_vco_capband);
        ret = $fscanf(fp, "%s %d", str, trx);
        ret = $fscanf(fp, "%s %x", str, divr);
        ret = $fscanf(fp, "%s %d", str, afc_cg_auto);
        ret = $fscanf(fp, "%s %d", str, rg_forceband_en);
        ret = $fscanf(fp, "%s %d", str, rg_vco_capband);
        ret = $fscanf(fp, "%s %d", str, rg_afc_vcostable_time);
        ret = $fscanf(fp, "%s %d", str, rg_afc_cnt_time);
        ret = $fscanf(fp, "%s %d", str, rg_aac_bypass);
        ret = $fscanf(fp, "%s %d", str, rg_aac_stable_time);
        ret = $fscanf(fp, "%s %d", str, rg_aac_cbandrange);
        ret = $fscanf(fp, "%s %d", str, rg_ini_ibsel_rx);
        ret = $fscanf(fp, "%s %d", str, rg_ini_ibsel_tx);
        $fclose(fp);
    end
endtask

task load_ncntr;
    begin
        if (rg_afc_cnt_time == 18) begin
            $readmemb({`LOG_DIR, "/", `NCNTR_M19}, ncntr_table);
        end
        else if (rg_afc_cnt_time == 63) begin
            $readmemb({`LOG_DIR, "/", `NCNTR_M64}, ncntr_table);
        end
    end
endtask

task afc_check;
    begin
        begin: WAIT_FINISH
            while(1) begin
                @(posedge clk);
                if (afc_finish) begin
                    disable WAIT_FINISH;
                end
            end
        end
        @(posedge clk);
        if (afc_vco_capband !== target_vco_capband) begin
            err_cnt = err_cnt + 1;
            $display("%t, case_num: %d, log_dir: %s", $time, case_num, log_dir);
            $display("    afc_vco_capband check fail, afc: %d, log:%d", afc_vco_capband, target_vco_capband);
        end
        else begin
            //$display("%t, case_num: %d, afc_vco_capband: %d, check pass.", $time, case_num, afc_vco_capband);
        end
        chk_cnt = chk_cnt + 1;
    end
endtask

task ndec_check;
    integer tmp;
    reg [22:0] mult;
    reg [13:0] chk;
    begin
        mult = divr[15:0]*(rg_afc_cnt_time[6:0] + 1);
        chk = mult[7] ? mult[21:8] + 1 : mult[21:8];
        wait(`AFC_TOP.st_curr == 8);
        if (`AFC_TOP.ndec_reg[13:0] !== chk[13:0]) begin
            err_cnt = err_cnt + 1;
            $display("%t, case_num: %d, log_dir: %s", $time, case_num, log_dir);
            $display("    ndec check fail, afc: %04x, log:%04x", `AFC_TOP.ndec_reg[13:0], chk[13:0]);
        end
        else begin
            //$display("%t, case_num: %d, ndec: %04x, check pass.", $time, case_num, chk[13:0]);
        end

    end
endtask

task disp_sum;
    begin
        $display("---------------------------------------------------");
        $display("---------------------------------------------------");
        $display("---------------------------------------------------");
        $display("  chk_cnt: %d", chk_cnt);
        if (err_cnt == 0) begin
            $display("      PASS.");
        end
        else begin
            $display("  err_cnt: %d", err_cnt);
            $display("      FAIL!");
        end
        $display("---------------------------------------------------");
    end
endtask
endmodule

