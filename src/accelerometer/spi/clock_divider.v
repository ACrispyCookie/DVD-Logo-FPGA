/*
This module generates a divided clock signal (`new_clk`) from an 
input clock (`clk`) using the Xilinx MMCM (Mixed-Mode Clock Manager). 
It also provides a synchronized locked signal (`locked_sync`) to 
indicate the stability of the generated clock.

Inputs:
  - clk: Primary input clock signal.
  - reset: Asynchronous reset signal. Resets the locked synchronization signal.

Outputs:
  - new_clk: Generated clock signal with a frequency divided as per the MMCM 
             configuration. (In this case 5Mhz)
  - locked_sync: Synchronized "locked" signal to indicate that the MMCM has 
                 locked onto the input clock and the output clock is stable.

Functionality:
  1. The module uses the Xilinx MMCME2_BASE primitive to create a new clock 
     signal with a specified frequency based on the input clock.
  2. The `locked` signal from the MMCM is synchronized with the divided clock
     (`new_clk`) to produce `locked_sync`.
  3. The module includes feedback connections to ensure proper MMCM operation.
*/
module clock_divider (
    clk,
    reset,
    new_clk,
    locked_sync
);

    input clk, reset;
    output new_clk;
    output reg locked_sync;

    wire locked;

    always @(posedge new_clk or posedge reset) begin
      if (reset)
        locked_sync <= 1'b0;
      else
        locked_sync <= locked;
    end

    MMCME2_BASE #(
      .CLKFBOUT_MULT_F(6.0),
      .CLKIN1_PERIOD(10.0),
      .CLKOUT0_DIVIDE_F(120.0),
      .DIVCLK_DIVIDE(1)         // Master division value (1-106)
    )
   
    MMCME2_BASE_inst (
      .CLKOUT0(new_clk),     // 1-bit output: CLKOUT0
      .CLKFBOUT(feedback),   // 1-bit output: Feedback clock
      .CLKIN1(clk),       // 1-bit input: Clock
      .CLKFBIN(feedback),      // 1-bit input: Feedback clock
      .LOCKED(locked)
    );
    
endmodule