// Synthesizable Verilog Implementation for a drawing unit that draws circles

`define stride 640

`define IDLE 0
`define SETUP 1
`define PLOT 2
`define CALC_X 3
`define CALC_Y 4


module drawing_implement( input  wire        clk,
                      input  wire        req,
                      output reg         ack,
                      output wire        busy,
                      input  wire [15:0] r0, // xc
                      input  wire [15:0] r1, // yc
                      input  wire [15:0] r2, // radius
                      input  wire [15:0] r3, // colour
                      input  wire [15:0] r4, // not used
                      input  wire [15:0] r5, // not used
                      input  wire [15:0] r6, // not used
                      input  wire [15:0] r7, // not used
                      output reg        de_req,
                      input  wire        de_ack,
                      output reg [17:0] de_addr,
                      output reg  [3:0] de_nbyte,
                      output wire        de_rnw, // not used
                      output reg [31:0] de_w_data,
                      input  wire [31:0] de_r_data ); // not used

/*----------------------------------------------------------------------------*/
// FSM state
reg [2:0] state;

// Internal variables for calculation
reg [17:0] pixel_addr; // pixel address of the current calculated point
reg [15:0] x; // x increment value
reg [15:0] y; // y increment value
reg [15:0] xc; // x coordinate for centre of circle
reg [15:0] yc; // y coordinate for centre of circle
reg signed [15:0] e; // error value
reg [2:0] octant; // octant to plot on
reg [7:0] colour; // colour of circle;

// Internal variables for status checking
reg octants_plotted; // 1 if all 8 octants have been plotted, 0 otherwise

/*----------------------------------------------------------------------------*/
// Respond to (spurious) req
always @ (posedge clk)			
  if (req && !ack) ack <= 1;
  else             ack <= 0;

/*----------------------------------------------------------------------------*/
// The initial state of the unit is its IDLE state
initial 
  begin
  state = `IDLE;
  end

/*----------------------------------------------------------------------------*/
// FSM and logic
always @ (posedge clk)
  begin
    case (state)
      // The IDLE state is where the unit does nothing but wait for a req signal
      `IDLE:
        begin
        reset_variables;
          if (req) // Start operations on req signal
            begin
              initialise;
              state <= `SETUP; 
            end
          else state <= `IDLE;
        end
      // The SETUP state calculates the pixel address to be plotted
      `SETUP:
        begin
          calc_pixel_addr;
          state <= `PLOT;
        end
      // The PLOT state asserts the output buses and pushes out a de_req signal to ask to plot
      `PLOT:
        begin
          if (!(x<y) && octant == 0) state <= `IDLE; // If we've plotted the entire circle then return back to the IDLE state
          else
            begin
              setup_output; // Set up de_addr, de_nbyte, de_w_data output buses based on the pixel address
              de_req <= 1; // Request to plot pixel
	      if (de_ack) 
	        begin
	          de_req <= 0; // Stop request to plot pixel
	          update_octant; // Change our next octant to be plotted
	          if (octants_plotted) state <= `CALC_X; // Only update the calculations if the full set of octants have been plotted
	          else state <= `SETUP;  
	        end     
	      else state <= `PLOT;
            end
        end        
      // X increment calculation as part of the circle algorithm
      `CALC_X: 
        begin
          x <= x+1;
          e <= e-2*x;
          state <= `CALC_Y;
        end  
      // Y increment calculation as part of the circle algorithm
      `CALC_Y:
        begin
          if (e < 0) 
            begin
              y <= y - 1;
              e <= e + 2*y;
            end
          state <= `SETUP;
        end
      default: state <= `IDLE;
    endcase
  end

/*----------------------------------------------------------------------------*/
// Initialise all internal variables in preparation for calculations
task initialise;
  begin
    xc <= r0;
    yc <= r1;
    x <= 0;
    y <= r2;
    e <= r2;
    colour <= r3[7:0];
    octant <= 0;
    octants_plotted <= 0;
    pixel_addr <= 0;
  end
endtask

/*----------------------------------------------------------------------------*/
// Reset internal variables to 0
task reset_variables;
  begin
    x <= 0;
    y <= 0;
    e <= 0;
    colour <= 0;
    octant <= 0;
    octants_plotted <= 0;
  end
endtask

/*----------------------------------------------------------------------------*/
// Set de_nbyte based on the last 2 bits of pixel_addr
task set_de_nbyte;
  begin
    case (pixel_addr[1:0])
      2'b00: de_nbyte <= 4'b1110;
      2'b01: de_nbyte <= 4'b1101;
      2'b10: de_nbyte <= 4'b1011;
      2'b11: de_nbyte <= 4'b0111;
      default: de_nbyte <= 0;
    endcase 
  end
endtask

/*----------------------------------------------------------------------------*/
// Calculates the new pixel address based on the current octant
task calc_pixel_addr;
  begin
    case (octant)
      3'b000: pixel_addr <= xc+x+`stride*(yc+y);
      3'b001: pixel_addr <= xc+y+`stride*(yc+x); 
      3'b010: pixel_addr <= xc+y+`stride*(yc-x); 
      3'b011: pixel_addr <= xc+x+`stride*(yc-y); 
      3'b100: pixel_addr <= xc-x+`stride*(yc-y); 
      3'b101: pixel_addr <= xc-y+`stride*(yc-x); 
      3'b110: pixel_addr <= xc-y+`stride*(yc+x);
      3'b111: pixel_addr <= xc-x+`stride*(yc+y);
      default: pixel_addr <= 0;
    endcase
  end
endtask

/*----------------------------------------------------------------------------*/
// Increases the octant by 1. If we've reached the 8th octant (3'b111) then reset back to octant 0.
task update_octant;
  begin
    if (octant != 3'b111) // If this is not the 8th octant then simply increment our current octant by 1
      begin
        octant <= octant + 1;
        octants_plotted <= 0; // At this moment, we still haven't finished plotting all the octants since we haven't incremented beyond the 8th octant
      end
    else // Otherwise cycle back to octant 0
      begin
        octant <= 0;
        octants_plotted <= 1; // At this moment, we're at a new set of octants so we'll have plotted all the octants prior to this moment
      end
  end
endtask

/*----------------------------------------------------------------------------*/
// Set up output buses for the pixel to plot
task setup_output;
  begin
    de_addr <= pixel_addr >> 2;
    // Our circle consists of only one colour so set each part of the output data bus to be that colour
    de_w_data[7:0] <= colour;
    de_w_data[15:8] <= colour;
    de_w_data[23:16] <= colour;
    de_w_data[31:24] <= colour;
    set_de_nbyte;
  end
endtask

/*----------------------------------------------------------------------------*/
// Assign statements for other outputs
assign busy = (state != `IDLE);
assign de_rnw = 0;

endmodule
