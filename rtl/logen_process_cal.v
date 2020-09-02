module logen_process_cal (
    input                       rstn,   // logen_rstn,
    input                       clk,
    // reg
    input                       logen_en,
    input                       rg_logen_cal_bypass,
    input       [1:0]           rg_logen_cnt_sel,
    input       [2:0]           rg_logen_vsel_man,  // mannual mode
    input       [2:0]           rg_logen_vsel_seg0,
    input       [2:0]           rg_logen_vsel_seg1,
    input       [2:0]           rg_logen_vsel_seg2,
    input       [2:0]           rg_logen_vsel_seg3,
    input       [2:0]           rg_logen_vsel_seg4,
    input       [5:0]           rg_logen_cntr_bound0,
    input       [5:0]           rg_logen_cntr_bound1,
    input       [5:0]           rg_logen_cntr_bound2,
    input       [5:0]           rg_logen_cntr_bound3,
    // output
    input       [13:0]          a2d_ncntr,
    output reg                  cntr_rstn,
    output reg                  cntr_en,
    output reg                  cntr_datasyn,
    output reg  [5:0]           logen_cntr_curr,
    output reg  [2:0]           ldo_logen_vsel
);

// fsm
localparam LOGEN_IDLE           = 3'd0;
localparam LOGEN_CNTR_RSTN      = 3'd1;
localparam LOGEN_CNTR_EN_PRE    = 3'd2;
localparam LOGEN_CNTR_EN        = 3'd3;
localparam LOGEN_CNTR_EN_POST   = 3'd4;
localparam LOGEN_CNTR_DATASYN   = 3'd5;
localparam LOGEN_LDOVSEL_UPDATE = 3'd6;
// fsm
reg     [2:0]                   st_curr;
reg     [2:0]                   st_next;
// cnt
reg     [2:0]                   logen_en_dly;
wire                            logen_en_pos;
wire                            logen_start;
wire                            logen_cnt_end;
reg     [4:0]                   temp_cnt;
reg     [4:0]                   logen_cnt_m1;
reg     [2:0]                   ldo_logen_vsel_next;
wire    [5:0]                   cntr_val;

// logen_en_dly
always @(posedge clk or negedge rstn)
    if (~rstn)
        logen_en_dly <= 0;
    else
        logen_en_dly <= {logen_dly[1:0], logen_en};
// logen_en_pos
assign logen_en_pos     = (~logen_en_dly[2]) & logen_en_dly[1];
assign logen_start      = logen_en_pos;
// logen_cnt_m1
always @(*)
    case (rg_logen_cnt_sel)
        2'b00:      logen_cnt_m1 = 7;
        2'b01:      logen_cnt_m1 = 11;
        2'b10:      logen_cnt_m1 = 15;
        default:    logen_cnt_m1 = 19;
    endcase
// logen_cnt_end
assign logen_cnt_end    = (temp_cnt == logen_cnt_m1);

//---------------------------------------------------------------------------
// FSM
//---------------------------------------------------------------------------
// fsm_sync
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        st_curr <= LOGEN_IDLE;
    else
        st_curr <= st_next;
// fsm_comb
always @(*) begin
    // default
    st_next = st_curr;
    // translate
    case (st_curr)
        LOGEN_IDLE: begin
            if (logen_start) begin
                st_next = LOGEN_CNTR_RSTN;
            end
        end
        LOGEN_CNTR_RSTN: begin
            st_next = LOGEN_CNTR_EN_PRE;
        end
        LOGEN_CNTR_EN_PRE: begin
            st_next = LOGEN_CNTR_EN;
        end
        LOGEN_CNTR_EN: begin
            if (logen_cnt_end)
                st_next = LOGEN_CNTR_EN_POST;
        end
        LOGEN_CNTR_EN_POST: begin
            st_next = LOGEN_CNTR_DATASYN;
        end
        LOGEN_CNTR_DATASYN: begin
            st_next = LOGEN_CAPBAND_UPDATE;
        end
        LOGEN_LDOVSEL_UPDATE: begin
            st_next = LOGEN_IDLE;
        end
        default: begin
            st_next = LOGEN_IDLE;
        end
    endcase
end

// temp_cnt
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        temp_cnt <= 0;
    else if (st_curr != LOGEN_CNTR_EN && st_next == LOGEN_CNTR_EN)
        temp_cnt <= 0;
    else if (st_curr == LOGEN_CNTR_EN)
        temp_cnt <= temp_cnt + 1;
// cntr_rstn
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        cntr_rstn <= 1'b1;
    else if (st_curr != LOGEN_CNTR_RSTN && st_next == LOGEN_CNTR_RSTN)
        cntr_rstn <= 1'b0;
    else
        cntr_rstn <= 1'b1;
// cntr_en
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        cntr_en <= 1'b0;
    else if (st_curr == LOGEN_CNTR_EN_PRE)
        cntr_en <= 1'b1;
    else if (st_curr == LOGEN_CNTR_EN && st_next != LOGEN_CNTR_EN)
        cntr_en <= 1'b0;
// cntr_datasyn
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        cntr_datasyn <= 1'b0;
    else if (st_curr == LOGEN_CNTR_EN_POST)
        cntr_datasyn <= 1'b1;
    else
        cntr_datasyn <= 1'b0;
// cntr_val
assign cntr_val = a2d_ncntr[9:4];
// ldo_logen_vsel_next
always @(*) begin
    if (cntr_val <= rg_logen_cntr_bound0)
        ldo_logen_vsel_next = rg_logen_vsel_seg0;
    else if (cntr_val <= rg_logen_cntr_bound1)
        ldo_logen_vsel_next = rg_logen_vsel_seg1;
    else if (cntr_val <= rg_logen_cntr_bound2)
        ldo_logen_vsel_next = rg_logen_vsel_seg2;
    else if (cntr_val <= rg_logen_cntr_bound3)
        ldo_logen_vsel_next = rg_logen_vsel_seg3;
    else
        ldo_logen_vsel_next = rg_logen_vsel_seg4;
end
// ldo_logen_vsel
always @(posedge clk_gated or negedge rstn)
    if (~rstn)
        ldo_logen_vsel  <= 3'b010;  // default, 950mv
    else if (rg_logen_cal_bypass)
        ldo_logen_vsel  <= rg_logen_vsel_man;
    else if (st_curr == LOGEN_LDOVSEL_UPDATE) begin
        logen_cntr_curr[5:0] <= cntr_val;
        ldo_logen_vsel  <= ldo_logen_vsel_next;
    end

endmodule

