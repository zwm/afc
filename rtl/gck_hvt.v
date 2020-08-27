module gck_hvt (
    input clk_in,
    input clk_en,
    input test_en,
    output clk_out
);

reg latch_out;

always @(clk_in or clk_en or test_en) begin
    if (~clk_in) begin
        latch_out <= clk_en | test_en;
    end
end

assign clk_out = clk_in & latch_out;

endmodule

