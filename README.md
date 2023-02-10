
# Bresenham Circle Drawing Unit
## Table of Contents

  * [🗺️ Overview]#%EF%B8%8F-overview)
  * [⚙️ Specification and how it works](%EF%B8%8F-specification-and-how-it-works)
  * [✍️ Design and Test Verification](#%EF%B8%8F-design-and-test-verification)
  * [📈 Results](#-results)
  * [✔️ Improvements to be made](#%EF%B8%8F-improvements-to-be-made)
  

## 🗺️ Overview

This is a Verilog implementation of a synchronous drawing unit that is capable of drawing circles to a 640x480 framestore using Bresenham's Circle Algorithm. The design is synthesisable to a Xlinx Spartan-3 FPGA.

## ⚙️ Specification and how it works

Below is a schematic of the drawing unit alongside its register-level documentation for all the parts of the drawing unit that are used.

![Schematic](media/drawing_unit.jpg)
![Documentation](media/documentation.jpg)

Bresenham's circle algorithm exploits the symmetric nature of a circle - we can divide the circle into 8 octants (thus each octant is 45 degrees) so that we only need to figure out how to draw a single octant, then perform reflections and swapping of x,y coordinates in the calculations of the single octant to be able to plot the rest of the octants. A decision parameter 'e' denotes whether (x+1, y-1) or (x+1, y) of the next pixel to be plotted is closer to the arc of the circle. The pseudocode is shown below.

```
x = 0; // incrememental value for x
y = r; // incremental value for y
plot ([x,y],[y,x],[x,-y],[-y,x],...); // Plot the 8 octants by reflections and swapping of x,y
e = y; // e denotes our decision parameter
while (x < y) // continue up to the 45° point
  x = x + 1;
  e = e - 2*x;
if (e < 0) //if e < 0 then (x+1, y-1) is closer to the arc of the circle
  y = y - 1;
  e = e + 2*y;
  plot ([x,y],[y,x],[x,-y],[-y,x],...);
```

## ✍️ Design and Test Verification

The test strategy is derived from the use of a stimulus file to simulate the drawing unit and view its waveforms. Simply viewing the waveforms is not enough to verify this unit as this is messy and unintuitive to read. I've developed a high-level model coded in Python in order to automate the testing procedure by comparing the outputs of the waveforms to the outputs of the high-level model - this forms the basis for my design verification.

(INSERT IMAGE)

The tests also need to be verified, strong test coverage is ensured by maintaining a relatively high block, expression and bit coverage. The coverage tool used is Cadence's Incisive Comprehensive Coverage.

(INSERT IMAGE)

## 📈 Results

The figure below demonstrates the drawing unit in action on a Virtual Screen.

![Output](media/output.jpg)

## ✔️ Improvements to be made

Despite the success of the unit, there are many crucial adjustments or improvements that can be made.

  * The design is highly serial. There are many calculations or operations that could've been done in the same state or in a previous state. For example, in the same state that the output buses are asserted, the calculations can be updated in the meantime instead of having separate states to do the calculations. This would reduce the number of states and thus will take less cycles to plot the circle.
  * Some multiplications can be replaced with shift operations to exploit the efficiency of shifter blocks. For example, e <= e + 2*y; should be e <= e + (y<<1);
  * Some internal registers can be smaller in size, e.g. use 10 bit registers instead of 16 bit registers for x centre coord and y centre coord as the framestore that the drawing unit plots on is only 640x480 resolution

