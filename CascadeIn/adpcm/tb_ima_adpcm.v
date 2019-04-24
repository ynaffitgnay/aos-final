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

include ima_adpcm_enc.v;
include ima_adpcm_dec.v;

module test(clk);
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

  //reg[7:0] inReg, decReg;

  // Variables to read file input into before copying to in-mem buffer
  reg[(BUFFER_BYTES << 3) - 1:0] inVal;
  reg[(BUFFER_BYTES << 3) - 1:0] encVal;
  reg[(BUFFER_BYTES << 3) - 1:0] decVal;

  reg[15:0] inIdx, encIdx, decIdx;

  // Buffers to hold file content
  reg[(BUFFER_BYTES << 3) - 1:0] inBuf [(TOTAL_IN_BYTES / BUFFER_BYTES) - 1:0];
  reg[(BUFFER_BYTES << 3) - 1:0] encBuf [(TOTAL_ENC_BYTES / BUFFER_BYTES) - 1:0];
  reg[(BUFFER_BYTES << 3) - 1:0] decBuf [(TOTAL_DEC_BYTES / BUFFER_BYTES) - 1:0];
  reg[31:0] inBytesRead, encBytesRead, decBytesRead;
 

  reg[3:0] mainState;
  reg[3:0] inState;
  reg[3:0] encState;
  reg[3:0] decState;

  reg[31:0] mCtr;
  reg[31:0] iCtr;
  reg[31:0] eCtr;
  reg[31:0] dCtr;

  parameter BUFFER_BYTES = 32;

  parameter TOTAL_IN_BYTES = 348160;
  parameter TOTAL_ENC_BYTES = 174080;
  parameter TOTAL_DEC_BYTES = 348160;
  
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

  stream instream = $fopen("test_in.bin");
  stream encstream = $fopen("test_enc.bin");
  stream decstream = $fopen("test_dec.bin");
  
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

    // Fill the input buffer
    for (inIdx = 0; inIdx < (TOTAL_IN_BYTES / BUFFER_BYTES); inIdx = inIdx + 1) begin
      if (!($eof(instream))) $get(instream, inVal);
      //$display("i: %d", inIdx);
    
      inBuf[inIdx] <= inVal;
    end

    for (encIdx = 0; encIdx < (TOTAL_ENC_BYTES / BUFFER_BYTES); encIdx = encIdx + 1) begin
      if (!($eof(encstream))) $get(encstream, encVal);
      //$display("e: %d", encIdx);
    
      encBuf[encIdx] <= encVal;
    end

    for (decIdx = 0; decIdx < (TOTAL_DEC_BYTES / BUFFER_BYTES); decIdx = decIdx + 1) begin
      if (!($eof(decstream))) $get(decstream, decVal);
      //$display("d: %d", decIdx);
    
      decBuf[decIdx] <= decVal;
    end
    

    $display("Done initializing");

  end

  //---------------------------------------------------------------------------------------
  // test bench implementation 
  // global signals generation
  always @(posedge clk) begin
    mCtr <= mCtr + 1;

    //$display("intmp: %h, enctmp: %h, dectmp: %h", intmp, enctmp, dectmp);


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
        //$display("In MAIN1 (should only display once)");

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
        //@(posedge clk);
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
        //if (iCtr == 0) $seek(instream, 0);
        inIdx <= 0;

        if (!rst) begin
          iCtr <= 0;
          inState <= IN2;
        end
      end // case: IN1
      
      // wait for reset release
      //while (rst) @(posedge clock);
      //repeat (50) @(posedge clock);  // 50 cycles

      IN2: begin
        if (iCtr >= 50) begin
          $display("Getting input byte");

          // read input samples file 
          $get(instream, inBuf);
          //intmp = $fgetc(instream);

          intmp <= inBuf[inIdx][(BUFFER_BYTES << 3) - 1:((BUFFER_BYTES << 3) - 8)];
          inBytesRead <= inBytesRead + 1;

          iCtr <= 0;
          inState <= IN3;
        end
      end // case: IN2

      IN3: begin
        //while (intmp != `EOF)
        //begin

        // Stop looping through inputs if eof

        // TODO: NEED TO FIX BHVR OF EOF. REPLACE WITH BYTES_READ
        //if ($eof(instream)) begin
        if (inBytesRead == TOTAL_IN_BYTES) begin
          $display("Reached eof");

          iCtr <= 0;
          inState <= IN5;
        end

        else begin
          if (iCtr == 0) begin
            // read the next character to form the new input sample 
            // Note that first byte is used as the low byte of the sample 
            inSamp[7:0] <= intmp;
            //bytes_read <= bytes_read + 1;
            //$display("bytes_read: %d", bytes_read);

            case (inBytesRead % BUFFER_BYTES) 
              1: inReg <= inBuf[55:48];
              3: inReg <= inBuf[39:32];
              5: inReg <= inBuf[23:16];
              7: inReg <= inBuf[7:0];
              default: $display("Unexpected number of bytes read for inSamp");
            endcase // case (inBytesRead % BUFFER_BYTES)

            //inSamp[15:8] <= $fgetc(instream);
            //$get(instream, inReg);
            inSamp[15:8] <= inReg;

            inBytesRead <= inBytesRead + 1;

            $display("inBytesRead: %d", inBytesRead);

            if ((inBytesRead % BUFFER_BYTES) == 0) begin
              $display("Reading more bytes");

              if (!($eof(instream))) $get(instream, inBuf);
            end

          end // if (iCtr == 0)

          //$display("inSamp: %h", inSamp);

          // sign input sample is valid 
          inValid <= 1'b1;

          // @(posedge clock);
          if (iCtr >= 1) begin
            iCtr <= 0;
            inState <= IN4;
          end
        end // else: !if($eof(instream))

      end // case: IN3


      IN4: begin
        // update the sample counter 
        if (iCtr == 0) begin 
          sampCount <= sampCount + 1;
          //inByteInc <= 0;

        end


        // wait for encoder input ready assertion to confirm the new sample was read
        // by the encoder.
        //while (!inReady)
        //  @(posedge clock);

        if (inReady) begin
          // read next character from the input file 
          //intmp = $fgetc(instream);

          //$get(instream, intmp);
          case (BYTES_READ % BUFFER_BYTES)
            0: intmp <= inBuf[63:56];
            2: intmp <= inBuf[47:40];
            4: intmp <= inBuf[31:24];
            6: intmp <= inBuf[15:8];
          endcase // case (BYTES_READ % BUFFER_BYTES)


          inBytesRead <= (sampCount << 1) + 1;
          $display("inbytesread; %d", inBytesRead);

          //if (!inByteInc) begin
          //  inBytesRead <= inBytesRead + 1;
          //  inByteInc <= 1;
          //end
          

          iCtr <= 0;
          inState <= IN3;
        end

      end // case: IN4

      IN5: begin
        // sign input is not valid 
        inValid <= 1'b0;
        //@(posedge clock);

        if (iCtr >= 1) begin
          //$display("Closing input file");
          // close input file 
          //$fclose(instream);

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
  //initial 
  //begin
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
        
        // open input file 
        //encstream = $fopen(`ENC_FILE, "rb");
        //if (eCtr == 0) $seek(encstream, 0);
        encIdx <= 0;

        if (!rst) begin
          $display("getting first enc byte");

          $get(encstream, enctmp);

          eCtr <= 0;
          encState <= ENC2;
        end
      end // case: ENC1
      

      // wait for reset release
      //while (rst) @(posedge clock);
    
      // encoder output compare loop 
      //enctmp = $fgetc(encstream);
      ENC2: begin
        if ($eof(encstream)) begin
          $display("Reached eof of encryption file");
          eCtr <= 0;
          encState <= ENC4;
        end

        else begin
          //while (enctmp != `EOF)  // can put this into a state machine
          //begin 
          // assign the expected value to a register with the same width 
          encExpVal <= enctmp;
          
          // wait for encoder output valid 
          //while (!encValid)
          //  @(posedge clock);
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
            $display("Error found in encoder output index %d.", encCount+1);
            $display("   (expected value 'h%h, got value 'h%h)", encExpVal, encPcm);
          end

          // wait for a few clock cycles before ending simulation 
          //repeat (20) @(posedge clock);
          if (eCtr >= 20) $finish();
        end // if (encPcm != encExpVal)

        else begin
      
          // update the encoded sample counter 
          if (eCtr == 0) encCount <= encCount + 1;
          // delay for a clock cycle after comparison 
          //@(posedge clock);

          if (eCtr >= 1) begin
            // read next char from input file 
            //enctmp = $fgetc(encstream);
            $display("encoder output correct!!!!!!!!!!");

            $get(encstream, enctmp);
            eCtr <= 0;
            encState <= ENC2;

          end
        end // else: !if(encPcm != encExpVal)
      end // case: ENC3

      ENC4: begin
        if (iCtr >= 1) begin
          $display("Would close input file here");
          // close input file 
          //$fclose(encstream);
          
          encDone <= 1;

          eCtr <= 0;
          encState <= ENC0;

        end
      end

      default: encState <= ENC0;

    endcase // case (encState)
   
  end // always @ (posedge clk)


  // decoder output checker - the decoder output is compared to the value read from 
  // the ADPCM decoded samples file. 
  //initial 
  //begin
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
        // open input file 
        //decstream = $fopen(`DEC_FILE, "rb");
        //if (dCtr == 0) $seek(decstream, 0);
        decIdx <= 0;

        
        // wait for reset release
        //while (rst) @(posedge clock);

        if (!rst) begin
          $display("Grabbing first dec byte");
          // decoder output compare loop
          
          //dectmp = $fgetc(decstream);
          $get(decstream, dectmp);

          dCtr <= 0;
          decState <= DEC2;
        end
      end // case: DEC1

      DEC2: begin
        // display simulation progress bar title 
        //$write("Simulation progress: ");
        if ($eof(decstream)) begin
          $display("Reached eof of dec file");
          dCtr <= 0;
          decState <= DEC4;
        end

        else begin    
          //while (dectmp != `EOF)
          //begin 
          // read the next char to form the expected 16 bit sample value
          
          if (dCtr == 0) begin  
            decExpVal[7:0] <= dectmp;

            $get(decstream, decReg);
            //decExpVal[15:8] <= $fgetc(decstream);
            decExpVal[15:8] <= decReg;
          end

          // wait for decoder output valid 
          //while (!decValid)
          //  @(posedge clock);
          
          if (decValid) begin
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
          //repeat (20) @(posedge clock);
          //$finish
          if (dCtr >= 20) $finish();

        end // if (decSamp != decExpVal)
        
        else begin
          // delay for a clock cycle after comparison 
          //@(posedge clock);
          // update the decoded sample counter 
          if (dCtr >= 1) begin
            decCount <= decCount + 1;

            //
            //// check if simulation progress should be displayed
            //if (dispCount[31:13] != (decCount >> 13))
            //  $write(".");
            // update the display counter 
            //dispCount = decCount;
            
            // read next char from input file 
            //dectmp = $fgetc(decstream);
            $get(decstream, dectmp);

            dCtr <= 0;
            decState <= DEC2;
          end // if (dCtr >= 1)
        end // else: !if(decSamp != decExpVal)
      end // case: DEC3

      DEC4: begin
        //$display("Would close decfile here");
        // close input file 
        //$fclose(decstream);

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
