
// Clock Frequency: 16MHz ~ 52MHz

module afc (
    input                       rstn,
    input                       clk,
    // input afc
    input                       afc_cg_auto,
    input                       afc_en,
    input                       trx,
    input       [15:0]          divr,
    input                       rg_forceband_en,
    input       [6:0]           rg_vco_capband,
    input       [1:0]           rg_afc_vcostable_time,
    input       [6:0]           rg_afc_cnt_time,
    input       [13:0]          a2d_afc_ncntr,
    // input aac
    input                       rg_aac_bypass,
    input       [1:0]           rg_aac_stable_time,
    input       [1:0]           rg_aac_cbandrange,
    input       [3:0]           rg_ini_ibsel_rx, // afc_ibvco initial val
    input       [3:0]           rg_ini_ibsel_tx, // afc_ibvco initial val
    input                       a2d_aac_pkd_state,
    // output
    output reg                  afc_openloop_en,
    output reg  [6:0]           afc_vco_capband,
    output reg                  afc_cntr_rstn,
    output reg                  afc_cntr_en,
    output reg                  afc_cntr_datasyn,
    output reg  [3:0]           afc_ibvco,
    output reg  [13:0]          afc_minerr,
    output reg                  afc_finish
);


// ctrl sync
reg     [1:0]                   afc_en_dly;
reg     [1:0]                   afc_cg_auto_dly;
reg     [1:0]                   rg_forceband_en_dly;
reg                             afc_en_sync_d1;
wire                            afc_en_sync;
wire                            afc_cg_auto_sync;
wire                            rg_forceband_en_sync;
wire                            afc_en_pos;
reg                             afc_en_pos_d1;
reg                             afc_en_pos_d2;
wire                            afc_end_pos;
reg                             afc_end_pos_d1;
reg                             afc_end_pos_d2;
wire                            afc_start;
wire                            clk_gated;
wire                            clk_en;
reg                             clk_en_auto;
// fsm
localparam IDLE                 = 5'd0;
localparam AFC_CAPBAND_INIT     = 5'd1;
localparam AFC_WAIT_VCOSTABLE   = 5'd2;
localparam AFC_CNTR_RSTN        = 5'd3;
localparam AFC_CNTR_EN_PRE      = 5'd4;
localparam AFC_CNTR_EN          = 5'd5;
localparam AFC_CNTR_EN_POST     = 5'd6;
localparam AFC_CNTR_DATASYN     = 5'd7;
localparam AFC_CAPBAND_UPDATE   = 5'd8;
localparam AFC_AAC_START        = 5'd9;
localparam AFC_AAC_DLY_2T       = 5'd10;
localparam AFC_AAC_DLY_T1       = 5'd11;
localparam AFC_AAC_IBVCO_UPDATE = 5'd12;
localparam AFC_AAC_END_T1       = 5'd13;
localparam AFC_SET_CAPBAND_OPT  = 5'd14;
localparam AFC_WAIT_T1          = 5'd15;
localparam AFC_END              = 5'd16;
reg     [4:0]                   st_curr;
reg     [4:0]                   st_next;
// cnt
reg                             afc_stage;
reg     [2:0]                   loop_cnt;
reg     [6:0]                   temp_cnt;
reg     [3:0]                   vcostable_time_m1;
wire                            afc_vcostable_end;
wire                            afc_cnt_end;
wire                            afc_loop_end;
// ndec
reg                             ndec_en;
reg     [2:0]                   ndec_cnt;
reg     [22:0]                  ndec_acc; // 16 + 7 = 23
wire    [22:0]                  ndec_acc_next;
reg     [13:0]                  ndec_reg;
reg     [22:0]                  divr_shift;
// err
reg     [13:0]                  err_min_abs; // abs
wire    [14:0]                  err_cur;
wire    [13:0]                  err_cur_abs; // abs
wire    [14:0]                  err_sub;
wire                            err_min_update;
wire                            err_sign;
reg     [6:0]                   vco_capband_opt;
// aac
wire                            afc_aac_2t_end;
wire                            afc_aac_t1_end;
reg     [3:0]                   aac_stabletime_m1;
reg                             a2d_aac_pkd_state_d1;
reg                             a2d_aac_pkd_state_d2;
wire                            a2d_aac_pkd_state_sync;
wire    [3:0]                   afc_ibvco_init;
wire    [7:0]                   m;

//---------------------------------------------------------------------------
// Sync & Cg
//---------------------------------------------------------------------------
// ctrl sync
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        afc_en_dly              <= 0;
        afc_en_sync_d1          <= 0;
        afc_cg_auto_dly         <= 0;
        rg_forceband_en_dly     <= 0;
    end
    else begin
        afc_en_dly              <= {afc_en_dly[0],              afc_en};
        afc_en_sync_d1          <= afc_en_sync;
        afc_cg_auto_dly         <= {afc_cg_auto_dly[0],         afc_cg_auto};
        rg_forceband_en_dly     <= {rg_forceband_en_dly[0],     rg_forceband_en};
    end
// afc_en_sync_d1
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        afc_en_sync_d1          <= 0;
    end
    else begin
        afc_en_sync_d1          <= afc_en_sync;
    end
// afc_en_pos_dly
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        afc_en_pos_d1           <= 0;
        afc_en_pos_d2           <= 0;
        afc_end_pos_d1          <= 0;
        afc_end_pos_d2          <= 0;
    end
    else begin
        afc_en_pos_d1           <= afc_en_pos;
        afc_en_pos_d2           <= afc_en_pos_d1;
        afc_end_pos_d1          <= afc_end_pos;
        afc_end_pos_d2          <= afc_end_pos_d1;
    end
// clk_en_auto
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        clk_en_auto             <= 0;
    end
    else if (afc_en_pos) begin
        clk_en_auto             <= 1;
    end
    else if (afc_end_pos_d2) begin
        clk_en_auto             <= 0;
    end
// sync
assign afc_en_sync              = afc_en_dly[1];
assign afc_cg_auto_sync         = afc_cg_auto_dly[1];
assign rg_forceband_en_sync     = rg_forceband_en_dly[1];
assign afc_en_pos               = afc_en_sync & (~afc_en_sync_d1);
assign afc_start                = afc_en_pos_d2 & (~rg_forceband_en_sync);
assign afc_end_pos              = st_curr == AFC_END;
assign clk_en                   = afc_cg_auto_sync ? clk_en_auto : 1'b1;
// cg
gck_hvt u_gck (clk, clk_en, 1'b0, clk_gated);

//---------------------------------------------------------------------------
// Gated Clk Domain
//---------------------------------------------------------------------------
// vcostable_time_m1
always @(*)
    case (rg_afc_vcostable_time)
        2'b00:      vcostable_time_m1 = 4'd1;
        2'b01:      vcostable_time_m1 = 4'd3;
        2'b10:      vcostable_time_m1 = 4'd7;
        default:    vcostable_time_m1 = 4'd15;
    endcase
// aac_stabletime_m1
always @(*)
    case (rg_aac_stable_time)
        2'b00:      aac_stabletime_m1 = 4'd1;
        2'b01:      aac_stabletime_m1 = 4'd3;
        2'b10:      aac_stabletime_m1 = 4'd7;
        default:    aac_stabletime_m1 = 4'd15;
    endcase
// afc_loop_end
assign afc_loop_end             = (loop_cnt == (afc_stage ? ({1'b0, rg_aac_cbandrange[1:0]} + 3'h1) : 3'h6));
// afc_vcostable_end
assign afc_vcostable_end        = (temp_cnt == {3'h0, vcostable_time_m1});
// afc_cnt_end
assign afc_cnt_end              = (temp_cnt == rg_afc_cnt_time[6:0]);
// afc_aac_2t_end
assign afc_aac_2t_end           = (temp_cnt == 6'h1);
// afc_aac_t1_end
assign afc_aac_t1_end           = (temp_cnt == {3'h0, aac_stabletime_m1});
// afc_ibvco_init
assign afc_ibvco_init           = trx ? rg_ini_ibsel_tx : rg_ini_ibsel_rx;
//---------------------------------------------------------------------------
// N_DEC
//---------------------------------------------------------------------------
// m
assign m                        = {1'b0, rg_afc_cnt_time[6:0]} + 1;
// ndec_acc_next
assign ndec_acc_next            = ndec_acc + divr_shift; // acc
// divr_shift
always @(*)
    case (ndec_cnt)
        3'd0:       divr_shift = m[0] ? {7'h0, divr      } : 23'h0;
        3'd1:       divr_shift = m[1] ? {6'h0, divr, 1'h0} : 23'h0;
        3'd2:       divr_shift = m[2] ? {5'h0, divr, 2'h0} : 23'h0;
        3'd3:       divr_shift = m[3] ? {4'h0, divr, 3'h0} : 23'h0;
        3'd4:       divr_shift = m[4] ? {3'h0, divr, 4'h0} : 23'h0;
        3'd5:       divr_shift = m[5] ? {2'h0, divr, 5'h0} : 23'h0;
        3'd6:       divr_shift = m[6] ? {1'h0, divr, 6'h0} : 23'h0;
        default:    divr_shift = m[7] ? {      divr, 7'h0} : 23'h0;
    endcase
// n_dec
always @(posedge clk_gated or negedge rstn)
    if (~rstn) begin
        ndec_en <= 0;
        ndec_cnt <= 0;
        ndec_acc <= 0;
        ndec_reg <= 0;
    end
    else if (st_curr == IDLE && afc_start) begin
        ndec_en <= 1;
        ndec_acc <= 0;
        ndec_cnt <= 0;
    end
    else if (ndec_en) begin
        if (ndec_cnt == 3'h7) begin // end of calculation
            ndec_en <= 0;
            ndec_reg <= ndec_acc_next[7] ? (ndec_acc_next[21:8] + 1) : ndec_acc_next[21:8]; // round
        end
        else begin
            ndec_cnt <= ndec_cnt + 1;
            ndec_acc <= ndec_acc_next;
        end
    end
//---------------------------------------------------------------------------
// FSM
//---------------------------------------------------------------------------
// fsm_sync
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        st_curr <= IDLE;
    else
        st_curr <= st_next;
// fsm_comb
always @(*) begin
    // default
    st_next = st_curr;
    // translate
    case (st_curr)
        IDLE: begin
            if (afc_start) begin // tbd ??? posedge ??
                st_next = AFC_CAPBAND_INIT;
            end
        end
        AFC_CAPBAND_INIT: begin
            st_next = AFC_WAIT_VCOSTABLE;
        end
        AFC_WAIT_VCOSTABLE: begin
            if (afc_vcostable_end)
                st_next = AFC_CNTR_RSTN;
        end
        AFC_CNTR_RSTN: begin
            st_next = AFC_CNTR_EN_PRE;
        end
        AFC_CNTR_EN_PRE: begin
            st_next = AFC_CNTR_EN;
        end
        AFC_CNTR_EN: begin
            if (afc_cnt_end)
                st_next = AFC_CNTR_EN_POST;
        end
        AFC_CNTR_EN_POST: begin
            st_next = AFC_CNTR_DATASYN;
        end
        AFC_CNTR_DATASYN: begin
            st_next = AFC_CAPBAND_UPDATE;
        end
        AFC_CAPBAND_UPDATE: begin
            if (afc_loop_end)
                st_next = AFC_SET_CAPBAND_OPT;
            else
                st_next = AFC_CAPBAND_INIT;
        end
        AFC_SET_CAPBAND_OPT: begin
            st_next = AFC_WAIT_T1;
        end
        AFC_WAIT_T1: begin
            if (afc_vcostable_end) begin
                if (afc_stage) begin
                    st_next = AFC_END;
                end
                else begin
                    if (rg_aac_bypass) begin
                        st_next = AFC_END;
                    end
                    else begin
                        st_next = AFC_AAC_START; // tbd !!!
                    end
                end
            end
        end
        AFC_AAC_START: begin
            st_next = AFC_AAC_DLY_2T;
        end
        AFC_AAC_DLY_2T: begin
            if (afc_aac_2t_end)
                st_next = AFC_AAC_DLY_T1;
        end
        AFC_AAC_DLY_T1: begin
            if (afc_aac_t1_end)
                st_next = AFC_AAC_IBVCO_UPDATE;
        end
        AFC_AAC_IBVCO_UPDATE: begin
            if (a2d_aac_pkd_state_sync)
                st_next = AFC_AAC_END_T1;
            else if (afc_ibvco == 4'h0)
                st_next = AFC_AAC_END_T1;
            else
                st_next = AFC_AAC_DLY_T1;
        end
        AFC_AAC_END_T1: begin
            if (afc_aac_t1_end)
                st_next = AFC_CAPBAND_INIT;
        end
        AFC_END: begin
            st_next = IDLE;
        end
        default: begin
            st_next = IDLE;
        end
    endcase
end

// afc_stage
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_stage <= 1'b0;
    else if (st_curr == IDLE && afc_start) // init
        afc_stage <= 1'b0;
    else if (st_curr == AFC_AAC_END_T1 && afc_aac_t1_end) // toggle
        afc_stage <= 1'b1;
// temp_cnt
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        temp_cnt <= 0;
    else if ((st_curr != AFC_WAIT_VCOSTABLE && st_next == AFC_WAIT_VCOSTABLE) ||
             (st_curr != AFC_CNTR_EN        && st_next == AFC_CNTR_EN       ) ||
             (st_curr != AFC_WAIT_T1        && st_next == AFC_WAIT_T1       ) ||
             (st_curr != AFC_AAC_DLY_2T     && st_next == AFC_AAC_DLY_2T    ) ||
             (st_curr != AFC_AAC_DLY_T1     && st_next == AFC_AAC_DLY_T1    ) ||
             (st_curr != AFC_AAC_END_T1     && st_next == AFC_AAC_END_T1    ))
        temp_cnt <= 0;
    else if ((st_curr == AFC_WAIT_VCOSTABLE) ||
             (st_curr == AFC_CNTR_EN       ) ||
             (st_curr == AFC_WAIT_T1       ) ||
             (st_curr == AFC_AAC_DLY_2T    ) ||
             (st_curr == AFC_AAC_DLY_T1    ) ||
             (st_curr == AFC_AAC_END_T1    ))
        temp_cnt <= temp_cnt + 1;
// loop_cnt
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        loop_cnt <= 0;
    else if (st_curr == IDLE && afc_start)
        loop_cnt <= 0;
    else if (st_curr == AFC_AAC_END_T1 && afc_aac_t1_end)
        loop_cnt <= 0;
    else if (st_curr == AFC_CAPBAND_UPDATE)
        loop_cnt <= loop_cnt + 1;
// err
assign err_cur                  = {1'b0, a2d_afc_ncntr} - {1'b0, ndec_reg}; // need sync?
assign err_cur_abs              = err_cur[14] ? ((err_cur[13:0] == 14'h0000) ? 14'h3fff : ((~err_cur[13:0]) + 1)) : err_cur[13:0];
assign err_sub                  = {1'b0, err_cur_abs} - {1'b0, err_min_abs};
assign err_min_update           = err_sub[14];
assign err_sign                 = err_cur[14];
// err_min_abs & afc_capband_opt
always @(posedge clk_gated or negedge rstn)
    if (~rstn) begin
        err_min_abs <= 14'h3fff;
        vco_capband_opt <= 7'b100_0000;
    end
    else if (st_curr == IDLE && afc_start) begin // init of afc1
        err_min_abs <= 14'h3fff;
        vco_capband_opt <= 7'b100_0000;
    end
    else if (st_curr == AFC_AAC_END_T1 && afc_aac_t1_end) begin // init of afc2
        err_min_abs <= 14'h3fff;
        //vco_capband_opt <= 7'b100_0000;
    end
    else if (st_curr == AFC_CAPBAND_UPDATE) begin // update
        if (err_min_update) begin
            err_min_abs <= err_cur_abs;
            vco_capband_opt <= afc_vco_capband;
        end
    end
// afc_vco_capband
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_vco_capband <= 7'b100_0000;
    else if (rg_forceband_en_sync) begin
        afc_vco_capband <= rg_vco_capband;
    end
    else if (st_curr == IDLE && afc_start) begin
        afc_vco_capband <= 7'b100_0000;
    end
    else if (st_curr == AFC_CAPBAND_INIT) begin
    end
    else if (st_curr == AFC_CAPBAND_UPDATE) begin
        // stage 0
        if (afc_stage == 0 && err_sign == 1) begin // current state modify
            case (loop_cnt)
                3'd0:       afc_vco_capband[6] <= 0;
                3'd1:       afc_vco_capband[5] <= 0;
                3'd2:       afc_vco_capband[4] <= 0;
                3'd3:       afc_vco_capband[3] <= 0;
                3'd4:       afc_vco_capband[2] <= 0;
                3'd5:       afc_vco_capband[1] <= 0;
                3'd6:       afc_vco_capband[0] <= 0;
            endcase
        end
        if (afc_stage == 0) begin // next state update
            case (loop_cnt)
                3'd0:       afc_vco_capband[5] <= 1;
                3'd1:       afc_vco_capband[4] <= 1;
                3'd2:       afc_vco_capband[3] <= 1;
                3'd3:       afc_vco_capband[2] <= 1;
                3'd4:       afc_vco_capband[1] <= 1;
                3'd5:       afc_vco_capband[0] <= 1;
            endcase
        end
        // stage 1
        if (afc_stage == 1) begin  // tbd ??? !!!
            if (err_sign)
                afc_vco_capband <= afc_vco_capband - 1;
            else
                afc_vco_capband <= afc_vco_capband + 1;
        end
    end
    else if (st_curr == AFC_SET_CAPBAND_OPT) begin
        afc_vco_capband <= vco_capband_opt;
    end
// afc_cntr_rstn
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_cntr_rstn <= 1'b1;
    else if (st_curr == AFC_WAIT_VCOSTABLE && st_next == AFC_CNTR_RSTN)
        afc_cntr_rstn <= 1'b0;
    //else if (st_curr == AFC_CNTR_RSTN)
    else
        afc_cntr_rstn <= 1'b1;
// afc_cntr_en
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_cntr_en <= 1'b0;
    else if (st_curr == AFC_CNTR_EN_PRE)
        afc_cntr_en <= 1'b1;
    else if (st_curr == AFC_CNTR_EN && st_next != AFC_CNTR_EN)
        afc_cntr_en <= 1'b0;
// afc_cntr_datasyn
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_cntr_datasyn <= 1'b0;
    else if (st_curr == AFC_CNTR_EN_POST)
        afc_cntr_datasyn <= 1'b1;
    //else if (st_curr == AFC_CNTR_EN && st_next != AFC_CNTR_EN)
    else
        afc_cntr_datasyn <= 1'b0;
// afc_openloop_en
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_openloop_en <= 0;
    else if (rg_forceband_en_sync)
        afc_openloop_en <= 0;
    else if (st_curr != IDLE)
        afc_openloop_en <= 1;
    else
        afc_openloop_en <= 0;
// afc_finish
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_finish <= 0;
    else if (rg_forceband_en_sync)
        afc_finish <= 0;
    //else if (st_curr != IDLE)
    else if (st_curr == IDLE & afc_start)
        afc_finish <= 0;
    else if (st_curr == AFC_END)
        afc_finish <= 1;
// afc_minerr
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_minerr <= 0;
    else if (rg_forceband_en_sync)
        afc_minerr <= 14'h1555;
    else if (st_curr == AFC_END)
        afc_minerr <= err_min_abs;
// a2d_aac_pkd_state_dly
always @(posedge clk_gated or negedge rstn)
    if (~rstn) begin
        a2d_aac_pkd_state_d1 <= 1;
        a2d_aac_pkd_state_d2 <= 1;
    end
    else if (st_curr != IDLE) begin
        a2d_aac_pkd_state_d1 <= a2d_aac_pkd_state;
        a2d_aac_pkd_state_d2 <= a2d_aac_pkd_state_d1;
    end
// a2d_aac_pkd_state_sync
assign a2d_aac_pkd_state_sync   = a2d_aac_pkd_state_d2;
// afc_ibvco
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        afc_ibvco <= afc_ibvco_init;
    else if (st_curr == IDLE && afc_start) // init
        afc_ibvco <= afc_ibvco_init;
    else if (st_curr == AFC_AAC_IBVCO_UPDATE) begin // update
        if (a2d_aac_pkd_state_sync == 1) begin
            afc_ibvco <= (afc_ibvco == 4'b1111) ? 4'b1111 : (afc_ibvco + 1);
        end
        else if (a2d_aac_pkd_state_sync == 0 && afc_ibvco != 0) begin
            afc_ibvco <= afc_ibvco - 1;
        end
    end

endmodule

