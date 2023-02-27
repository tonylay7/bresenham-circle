localparam PERIOD = 5; // Clock Period

localparam RED = 16'h00E0; // Pure Red Colour
localparam GREEN = 16'h001C; // Pure Green Colour
localparam BLUE = 16'h0003; // Pure Blue Colour
localparam YELLOW = 16'h00FC; // Pure Blue Colour
localparam WHITE = 16'h00FF; // Pure White Colour
localparam BLACK = 16'h0000; // Pure Black Colour
localparam GREY = 16'h0092; // Pure Grey Colour

reg sim_done; // sim_done = 1 when the simulation has finished, 0 otherwise
integer log_file; // The file to write outputs to

// Task to clear registers
task clear_reg;
	begin
	r0 = 16'hX;
	r1 = 16'hX;
	r2 = 16'hX;
	r3 = 16'hX;
	r4 = 16'hX;
	r5 = 16'hX;
	r6 = 16'hX;
	r7 = 16'hX;
	end
endtask

// Task to perform strobe control (handshaking)
task strobe (input [15:0] xc, yc, r, colour);
	begin
	r0 = xc;
	r1 = yc;
	r2 = r;
	r3 = colour;
	#PERIOD
	// Initiate handshake
	req = 1;
	// Wait until acknowledgement occurs then clear registers and remove request
	while (ack == 0) #PERIOD;
	clear_reg;
	req = 0;
	// Wait until not busy
	while (busy == 1) #PERIOD;
	#(10*PERIOD);
	end
endtask

// Clock Setup
initial
begin
clk = 0;
forever #PERIOD clk = !clk;
end

// De_ack high for a single clock period when de_req is high
always @ (posedge de_req) begin
#PERIOD de_ack = !de_ack;
#(PERIOD*2) de_ack = !de_ack; // Make de_ack high for a full clock period
end

always @ (posedge req)
  begin
    $fwrite(log_file, "%x,%x,%x\n", r0,r1,r2); // Write the input circle data to the file
  end
 
always @ (posedge de_ack)
  begin
    $fwrite(log_file, "%x %x\n", de_addr,de_nbyte); // Write the output de_addr and de_nbyte to the file
  end

always @(posedge sim_done)
  begin
    $fclose(log_file); // When the simulation is done then close the file
    $finish;
  end

initial
begin
#100
sim_done = 0;
log_file = $fopen("output.txt","w"); // Open file to log to
// Check that the unit waits until an input request arrives (expected no output changes with this input data)
r0 = 10;
r1 = 10;
r2 = 20;
r3 = 0;
r6 = BLUE;
#100

// Prepare for strobe tests
clear_reg;
de_ack = 0;
de_r_data = 0;

// Strobe tests
repeat (3) strobe(320,320,$urandom%10,RED); // Create circles of different small sizes at random, centred around the middle of the framestore
repeat (10) strobe(320,320,$urandom%100,GREEN); // Create circles of different (potentially large) sizes at random, centred around the middle of the framestore
repeat (10) strobe($urandom%640,$urandom%640,$urandom%50,BLUE); // Create circles of different (potentially large) sizes at random, centred around random coordinates
strobe(16'hFFFF,16'hFFFF,16'hFFFF,WHITE); // See what happens when we max out values in the registers
strobe(0,0,0,BLACK);// See what happens when we provide nothing in the registers

// Colour tests
strobe(320,320,20,RED);
strobe(320,320,20,BLUE);
strobe(320,320,20,GREEN);
strobe(320,320,20,YELLOW);
strobe(320,320,20,BLACK);
strobe(320,320,20,WHITE);
strobe(320,320,20,GREY);
#10000
sim_done = 1;
end




