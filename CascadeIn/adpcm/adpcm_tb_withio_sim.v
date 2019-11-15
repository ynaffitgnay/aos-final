//---------------------------------------------------------------------------------------
//  Project:  ADPCM Encoder / Decoder 
// 
//  Filename:  tb_ima_adpcm.v      (April 26, 2010 )
// 
//  Author(s):  Moti Litochevski 
// 
//  Description:
//    This file implements the ADPCM encoder & decoder test bench. The input samples 
//    to be encoded are read from a binary input file. The encoder stream output and 
//    decoded samples are also compared with binary files generated by the Scilab 
//    simulation.
//
//---------------------------------------------------------------------------------------
//
//  To Do: 
//  - 
// 
//---------------------------------------------------------------------------------------
// 
//  Copyright (C) 2010 Moti Litochevski 
// 
//  This source file may be used and distributed without restriction provided that this 
//  copyright statement is not removed from the file and that any derivative work 
//  contains the original copyright notice and the associated disclaimer.
//
//  THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES, 
//  INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTIBILITY AND 
//  FITNESS FOR A PARTICULAR PURPOSE. 
// 
//---------------------------------------------------------------------------------------
// Refactored to run on Cascade in April 2019 by Tiffany Yang

`include "ima_adpcm_enc.v"
`include "ima_adpcm_dec.v"

module test(clk);
  parameter BUFFER_BYTES = 32;
 
  parameter MAIN0 = 0;
  parameter MAIN1 = 1;
  parameter MAIN2 = 2;

  parameter IN0 = 0;
  parameter IN1 = 1;
  parameter IN2 = 2;
  parameter IN3 = 3;
  parameter IN4 = 4;
  parameter IN5 = 5;

  parameter ENC0 = 0;
  parameter ENC1 = 1;
  parameter ENC2 = 2;
  parameter ENC3 = 3;
  parameter ENC4 = 4;
  
  parameter DEC0 = 0;
  parameter DEC1 = 1;
  parameter DEC2 = 2;
  parameter DEC3 = 3;
  parameter DEC4 = 4;

  parameter TESTS_TO_RUN = 1;

  input wire clk;

  //---------------------------------------------------------------------------------------
  // internal signal  
  reg rst;        // global reset 
  reg [15:0] inSamp;    // encoder input sample 
  reg inValid;      // encoder input valid flag 
  wire inReady;      // encoder input ready indication 
  wire [3:0] encPcm;    // encoder encoded output value 
  wire encValid;      // encoder output valid flag
  wire decReady;     // decoder ready for input indication
  wire [15:0] decSamp;  // decoder output sample value 
  wire decValid;      // decoder output valid flag 
  integer sampCount, encCount, decCount;

  reg [7:0] intmp, enctmp, dectmp;
  reg [3:0] encExpVal;
  reg [15:0] decExpVal;
  reg [31:0] dispCount;

  reg inDone, encDone, decDone;

  reg[31:0] testCount;

  reg[7:0] inReg, decReg;

  // Variables to read file input into before copying to in-mem buffer
  reg[(BUFFER_BYTES << 3) - 1:0] inVal;
  reg[(BUFFER_BYTES << 3) - 1:0] encVal;
  reg[(BUFFER_BYTES << 3) - 1:0] decVal;

  reg[15:0] inIdx, encIdx, decIdx;

  reg[31:0] inBytesRead, encBytesRead, decBytesRead;
 
  reg[3:0] mainState;
  reg[3:0] inState;
  reg[3:0] encState;
  reg[3:0] decState;

  reg[31:0] mCtr;
  reg[31:0] iCtr;
  reg[31:0] eCtr;
  reg[31:0] dCtr;  
  
  // NOTE: Cascade does not like input files to be outside of
  // the Cascade home directory. Make sure to copy these into
  // the home directory (at least until the path gets fixed)
  integer instream = $fopen("test_in_bin.txt", "r");
  integer encstream = $fopen("test_enc_bin.txt", "r");
  integer decstream = $fopen("test_dec_bin.txt", "r");
  
  initial begin
    $display("Initializing");

    testCount = 0;

    mCtr = 0;
    mainState = 0;

    iCtr = 0;
    inState = 0;

    eCtr = 0;
    encState = 0;

    dCtr = 0;
    decState = 0;

    $display("Done initializing");

  end

  //---------------------------------------------------------------------------------------
  // test bench implementation 
  // global signals generation
  always @(posedge clk) begin
    mCtr <= mCtr + 1;

    if (testCount >= TESTS_TO_RUN) $finish(1);

    case (mainState)
      MAIN0: begin
        rst <= 1;

        inDone <= 0;
        encDone <= 0;
        decDone <= 0;

        if (mCtr >= 2) begin
          $display("");
          $display("IMA ADPCM encoder & decoder simulation");
          $display("--------------------------------------");
          mCtr <= 0;
          mainState <= MAIN1;
        end
      end

      MAIN1: begin
        rst <= 0;
        
        mCtr <= 0;
        mainState <= MAIN2;
      end // case: MAIN1

      MAIN2: begin
        if (inDone && encDone && decDone) begin
          $display("Test %d done!. Count: %d", testCount , mCtr);

          testCount <= testCount + 1;
          mCtr <= 0;
          mainState <= MAIN0;
        end
      end
         
    endcase // case (mainState)        
  end 

  //------------------------------------------------------------------
  // encoder input samples read process 
  always @(posedge clk) begin
    iCtr <= iCtr + 1;
    if (rst) inState <= IN1;

    case (inState)
      IN0: begin
        iCtr <= 0;
      end

      IN1: begin
        // clear encoder input signal 
        inSamp <= 16'b0;
        inValid <= 1'b0;
        // clear samples counter 
        sampCount <= 0;
        inBytesRead <= 0;

        // binary input file
        if (iCtr == 0) begin
          $rewind(instream);
          // Read beginning of input file
          $fread(instream, inVal);
        end

        inIdx <= 0;

        if (!rst) begin
          iCtr <= 0;
          inState <= IN2;
        end
      end // case: IN1
      
      IN2: begin
        if (iCtr >= 50) begin
          $display("Getting input byte");

          intmp <= inVal[(BUFFER_BYTES << 3) - 1:(BUFFER_BYTES << 3) - 8];
          inBytesRead <= inBytesRead + 1;

          $display("inBuf[%d] = %h%h%h%h%h%h%h%h", inIdx, 
                   inVal[255:224],
                   inVal[223:192],
                   inVal[191:160],
                   inVal[159:128],
                   inVal[127:96],
                   inVal[95:64],
                   inVal[63:32],
                   inVal[31:0]);


          iCtr <= 0;
          inState <= IN3;
        end
      end // case: IN2

      IN3: begin
        if ($feof(instream)) begin
          $display("Reached eof");

          iCtr <= 0;
          inState <= IN5;
        end

        else begin
          if (iCtr == 0) begin
            // read the next character to form the new input sample 
            // Note that first byte is used as the low byte of the sample 
            inSamp[7:0] <= intmp;

            case (inBytesRead % BUFFER_BYTES)
              1:  inSamp[15:8] <= inVal[247:240];
              3:  inSamp[15:8] <= inVal[231:224];
              5:  inSamp[15:8] <= inVal[215:208];
              7:  inSamp[15:8] <= inVal[199:192];
              9:  inSamp[15:8] <= inVal[183:176];
              11: inSamp[15:8] <= inVal[167:160];
              13: inSamp[15:8] <= inVal[151:144];
              15: inSamp[15:8] <= inVal[135:128];
              17: inSamp[15:8] <= inVal[119:112];
              19: inSamp[15:8] <= inVal[103:96];
              21: inSamp[15:8] <= inVal[87:80];
              23: inSamp[15:8] <= inVal[71:64];
              25: inSamp[15:8] <= inVal[55:48];
              27: inSamp[15:8] <= inVal[39:32];
              29: inSamp[15:8] <= inVal[23:16];
              31: inSamp[15:8] <= inVal[7:0];
              default: $display("Unexpected number of bytes read for inSamp");

            endcase // case (inBytesRead % BUFFER_BYTES)

            inBytesRead <= inBytesRead + 1;
          end // if (iCtr == 0)

          if (iCtr == 1) begin
            // sign input sample is valid (should be able to do this at iCtr = 0)
            inValid <= 1'b1;

            if ((inBytesRead % BUFFER_BYTES) == 0) begin
              inIdx <= inIdx + 1;
              if (!($feof(instream))) $fread(instream, inVal);

              $display("inBuf[%d] = %h%h%h%h%h%h%h%h", inIdx, 
                   inVal[255:224],
                   inVal[223:192],
                   inVal[191:160],
                   inVal[159:128],
                   inVal[127:96],
                   inVal[95:64],
                   inVal[63:32],
                   inVal[31:0]);
            end // if ((inBytesRead % BUFFER_BYTES) == 0)

            // Transition to next state
            iCtr <= 0;
            inState <= IN4;
          end // if (iCtr == 1)
        end // else: !if($eof(instream))

      end // case: IN3


      IN4: begin
        // update the sample counter 
        if (iCtr == 0) begin 
          sampCount <= sampCount + 1;
          $display("Sample count: %d", sampCount);

        end


        // wait for encoder input ready assertion to confirm the new sample was read
        // by the encoder.
        if (inReady) begin
          case (inBytesRead % BUFFER_BYTES)
            0:  intmp <= inVal[255:248];
            2:  intmp <= inVal[239:232];
            4:  intmp <= inVal[223:216];
            6:  intmp <= inVal[207:200];
            8:  intmp <= inVal[191:184];
            10: intmp <= inVal[175:168];
            12: intmp <= inVal[159:152];
            14: intmp <= inVal[143:136];
            16: intmp <= inVal[127:120];
            18: intmp <= inVal[111:104];
            20: intmp <= inVal[95:88];
            22: intmp <= inVal[79:72];
            24: intmp <= inVal[63:56];
            26: intmp <= inVal[47:40];
            28: intmp <= inVal[31:24];
            30: intmp <= inVal[15:8];
            default: $display("Unexpected value");

          endcase // case (inBytesRead % BUFFER_BYTES)

          inBytesRead <= (sampCount << 1) + 1;
          $display("inbytesread; %d", inBytesRead);          

          iCtr <= 0;
          inState <= IN3;
        end

      end // case: IN4

      IN5: begin
        // sign input is not valid 
        inValid <= 1'b0;

        if (iCtr >= 1) begin

          inDone <= 1;

          iCtr <= 0;
          inState <= IN0;
        end
      end // case: IN5
      
      default: inState <= IN0;
    endcase // case (inState)

  end // always @ (posedge clk)


  // encoder output checker - the encoder output is compared to the value read from 
  // the ADPCM coded samples file. 
  always @(posedge clk) begin
    eCtr <= eCtr + 1;
    if (rst) encState <= ENC1;

    case(encState)
      ENC0: begin
        eCtr <= 0;
      end

      ENC1: begin
        // clear encoded sample value 
        encCount <= 0;
        encBytesRead <= 0;
        
        if (eCtr == 0) begin
          $rewind(encstream);
          $fread(encstream, encVal);
        end

        encIdx <= 0;

        if (!rst) begin
          $display("getting first enc byte");

          enctmp <= encVal[(BUFFER_BYTES << 3) - 1:(BUFFER_BYTES << 3) - 8];
          encBytesRead <= encBytesRead + 1;

          $display("encBuf[%d] = %h%h%h%h%h%h%h%h", encIdx, 
                   encVal[255:224],
                   encVal[223:192],
                   encVal[191:160],
                   encVal[159:128],
                   encVal[127:96],
                   encVal[95:64],
                   encVal[63:32],
                   encVal[31:0]);


          eCtr <= 0;
          encState <= ENC2;
        end
      end // case: ENC1
      
      // encoder output compare loop 
      ENC2: begin
        if ($feof(encstream)) begin
          $display("Reached eof of encryption file");
          eCtr <= 0;
          encState <= ENC4;
        end

        else begin
          // assign the expected value to a register with the same width 
          encExpVal <= enctmp;
          
          // wait for encoder output valid 
          if (encValid) begin
            eCtr <= 0;
            encState <= ENC3;
          end
        end // else: !if($eof(encstream))
        
      end // case: ENC2  

      ENC3: begin
        // compare the encoded value with the value read from the input file 
        if (encPcm != encExpVal) begin 
          // announce error detection and exit simulation
          if (eCtr == 0) begin
            $display(" Error!");
            $display("Error found in encoder output index %d.", encCount + 1);
            $display("   (expected value 'h%h, got value 'h%h). encIdx: %d, inIdx: %d, decIdx: %d", encExpVal, encPcm, encIdx, inIdx, decIdx);            
          end

          // wait for a few clock cycles before ending simulation 
          if (eCtr >= 20) $finish();
        end // if (encPcm != encExpVal)

        else begin
          $display("encoder output correct. expected %h, got %h", encExpVal, encPcm);
          // update the encoded sample counter 
          if (eCtr == 0) encCount <= encCount + 1;

          // delay for a clock cycle after comparison 
          if (eCtr == 1) begin
            // read next char from input buffer           
            case (encBytesRead % BUFFER_BYTES)
              0:  enctmp <= encVal[255:248];
              1:  enctmp <= encVal[247:240];
              2:  enctmp <= encVal[239:232];
              3:  enctmp <= encVal[231:224];
              4:  enctmp <= encVal[223:216];
              5:  enctmp <= encVal[215:208];
              6:  enctmp <= encVal[207:200];
              7:  enctmp <= encVal[199:192];
              8:  enctmp <= encVal[191:184];
              9:  enctmp <= encVal[183:176];
              10: enctmp <= encVal[175:168];
              11: enctmp <= encVal[167:160];
              12: enctmp <= encVal[159:152];
              13: enctmp <= encVal[151:144];
              14: enctmp <= encVal[143:136];
              15: enctmp <= encVal[135:128];
              16: enctmp <= encVal[127:120];
              17: enctmp <= encVal[119:112];
              18: enctmp <= encVal[111:104];
              19: enctmp <= encVal[103:96];
              20: enctmp <= encVal[95:88];
              21: enctmp <= encVal[87:80];
              22: enctmp <= encVal[79:72];
              23: enctmp <= encVal[71:64];
              24: enctmp <= encVal[63:56];
              25: enctmp <= encVal[55:48];
              26: enctmp <= encVal[47:40];
              27: enctmp <= encVal[39:32];
              28: enctmp <= encVal[31:24];
              29: enctmp <= encVal[23:16];
              30: enctmp <= encVal[15:8];
              31: enctmp <= encVal[7:0];
              default: $display("Unexpected value when filling in enctmp");

            endcase // case (encBytesRead % BUFFER_BYTES)

            encBytesRead <= encBytesRead + 1;
          end // if (eCtr == 1)

          if (eCtr == 2) begin
            $display("encBytesRead: %d", encBytesRead);

            if ((encBytesRead % BUFFER_BYTES) == 0) begin
              $display("Reading more enc bytes\n");
              encIdx <= encIdx + 1;
              
              if (!($feof(encstream))) $fread(encstream, encVal);

              $display("encBuf[%d] = %h%h%h%h%h%h%h%h", encIdx + 1, 
                   encVal[255:224],
                   encVal[223:192],
                   encVal[191:160],
                   encVal[159:128],
                   encVal[127:96],
                   encVal[95:64],
                   encVal[63:32],
                   encVal[31:0]);
            end // if ((encBytesRead % BUFFER_BYTES) == 0)
            
            eCtr <= 0;
            encState <= ENC2;

          end // if (eCtr == 2)
        end // else: !if(encPcm != encExpVal)
      end // case: ENC3

      ENC4: begin          
        encDone <= 1;

        eCtr <= 0;
        encState <= ENC0;

      end

      default: encState <= ENC0;

    endcase // case (encState)
   
  end // always @ (posedge clk)


  // decoder output checker - the decoder output is compared to the value read from 
  // the ADPCM decoded samples file. 
  always @(posedge clk) begin
    dCtr <= dCtr + 1;
    if (rst) decState <= DEC1;

    case (decState)
      DEC0: begin
        dCtr <= 0;
      end

      DEC1: begin        
        // clear decoded sample value 
        decCount <= 0;
        dispCount <= 0;

        decBytesRead <= 0;

        // open input file
        if (dCtr == 0) begin
          $rewind(decstream);
          $fread(decstream, decVal);
        end

        decIdx <= 0;

        if (!rst) begin
          $display("Grabbing first dec byte");

          // decoder output compare loop          
          dectmp <= decVal[(BUFFER_BYTES << 3) - 1:(BUFFER_BYTES << 3) - 8];
          decBytesRead <= decBytesRead + 1;

                   $display("decBuf[%d] = %h%h%h%h%h%h%h%h", decIdx, 
                   decVal[255:224],
                   decVal[223:192],
                   decVal[191:160],
                   decVal[159:128],
                   decVal[127:96],
                   decVal[95:64],
                   decVal[63:32],
                   decVal[31:0]);

          dCtr <= 0;
          decState <= DEC2;
        end
      end // case: DEC1

      DEC2: begin
        if ($feof(decstream)) begin
          $display("Reached eof of dec file");
          dCtr <= 0;
          decState <= DEC4;
        end

        else begin    
          // read the next char to form the expected 16 bit sample value          
          if (dCtr == 0) begin  
            decExpVal[7:0] <= dectmp;

            case (decBytesRead % BUFFER_BYTES)
              1:  decExpVal[15:8] <= decVal[247:240];
              3:  decExpVal[15:8] <= decVal[231:224];
              5:  decExpVal[15:8] <= decVal[215:208];
              7:  decExpVal[15:8] <= decVal[199:192];
              9:  decExpVal[15:8] <= decVal[183:176];
              11: decExpVal[15:8] <= decVal[167:160];
              13: decExpVal[15:8] <= decVal[151:144];
              15: decExpVal[15:8] <= decVal[135:128];
              17: decExpVal[15:8] <= decVal[119:112];
              19: decExpVal[15:8] <= decVal[103:96];
              21: decExpVal[15:8] <= decVal[87:80];
              23: decExpVal[15:8] <= decVal[71:64];
              25: decExpVal[15:8] <= decVal[55:48];
              27: decExpVal[15:8] <= decVal[39:32];
              29: decExpVal[15:8] <= decVal[23:16];
              31: decExpVal[15:8] <= decVal[7:0];
              default: $display("Unexpected number of bytes read for decExpVal");

            endcase // case (inBytesRead % BUFFER_BYTES)

            decBytesRead <= decBytesRead + 1;
            $display("decBytesRead: %d", decBytesRead);
           
          end // if (dCtr == 0)

          if (dCtr == 1) begin
            if ((decBytesRead % BUFFER_BYTES) == 0) begin
              $display("Reading more dec bytes");
              
              decIdx <= decIdx + 1;
              if (!($feof(decstream))) $fread(decstream, decVal);

              $display("decBuf[%d] = %h%h%h%h%h%h%h%h", decIdx, 
                   decVal[255:224],
                   decVal[223:192],
                   decVal[191:160],
                   decVal[159:128],
                   decVal[127:96],
                   decVal[95:64],
                   decVal[63:32],
                   decVal[31:0]);
            end
          end

          // wait for decoder output valid 
          if (decValid && (dCtr >= 1)) begin
            dCtr <= 0;
            decState <= DEC3;
          end
        end // else: !if($eof(decstream))

      end // case: DEC2

      DEC3: begin        
        // compare the decoded value with the value read from the input file 
        if (decSamp != decExpVal) begin
          if (dCtr == 0) begin
            // announce error detection and exit simulation 
            $display(" Error!");
            $display("Error found in decoder output index %d.", decCount+1);
            $display("   (expected value 'h%h, got value 'h%h)", decExpVal, decSamp);
          end

          // wait for a few clock cycles before ending simulation 
          if (dCtr >= 20) $finish();

        end // if (decSamp != decExpVal)
        
        else begin
          $display("Dec correct! expected: %h, got: %h", decExpVal, decSamp);

          // delay for a clock cycle after comparison 
          // update the decoded sample counter 
          if (dCtr == 1) begin
            decCount <= decCount + 1;

            case (decBytesRead % BUFFER_BYTES)
              0:  dectmp <= decVal[255:248];
              2:  dectmp <= decVal[239:232];
              4:  dectmp <= decVal[223:216];
              6:  dectmp <= decVal[207:200];
              8:  dectmp <= decVal[191:184];
              10: dectmp <= decVal[175:168];
              12: dectmp <= decVal[159:152];
              14: dectmp <= decVal[143:136];
              16: dectmp <= decVal[127:120];
              18: dectmp <= decVal[111:104];
              20: dectmp <= decVal[95:88];
              22: dectmp <= decVal[79:72];
              24: dectmp <= decVal[63:56];
              26: dectmp <= decVal[47:40];
              28: dectmp <= decVal[31:24];
              30: dectmp <= decVal[15:8];
              default: $display("Unexpected value");

            endcase // case (inBytesRead % BUFFER_BYTES)


            decBytesRead <= decBytesRead + 1;

          end // if (dCtr == 1)

          if (dCtr == 2) begin
            $display("decbytesread; %d", decBytesRead);

            dCtr <= 0;
            decState <= DEC2;
          end // if (dCtr >= 1)
        end // else: !if(decSamp != decExpVal)
      end // case: DEC3

      DEC4: begin
        // when decoder output is done announce simulation was successful 
        $display(" Done");
        $display("Simulation ended successfully after %0d samples", decCount);
        //$finish;
        decDone <= 1;

        dCtr <= 0;
        decState <= 0;
      end // case: DEC4

      default: decState <= DEC0;

    endcase // case (decState)
  end // always @ (posedge clk)

      
    
/* */
  //------------------------------------------------------------------
  // device under test 
  // Encoder instance 
  ima_adpcm_enc enc
    (
     .clock(clk), 
     .reset(rst), 
     .inSamp(inSamp), 
     .inValid(inValid),
     .inReady(inReady),
     .outPCM(encPcm), 
     .outValid(encValid), 
     .outPredictSamp(/* not used */), 
     .outStepIndex(/* not used */) 
     );

  // Decoder instance 
  ima_adpcm_dec dec 
    (
     .clock(clk), 
     .reset(rst), 
     .inPCM(encPcm), 
     .inValid(encValid),
     .inReady(decReady),
     .inPredictSamp(16'b0), 
     .inStepIndex(7'b0), 
     .inStateLoad(1'b0), 
     .outSamp(decSamp), 
     .outValid(decValid) 
     );

endmodule

test t(clock.val);
