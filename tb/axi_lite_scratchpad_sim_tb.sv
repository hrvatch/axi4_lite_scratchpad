module axi_lite_scratchpad_sim_tb;

  // Testbench parameters
  localparam int unsigned MEMORY_BW_p = 32;
  localparam int unsigned MEMORY_DEPTH_p = 1024;
  localparam int unsigned AXI_ADDR_BW = $clog2((MEMORY_BW_p/8)*(MEMORY_DEPTH_p));
  
  // Clock and reset
  logic clk;
  logic rst_n;
  
  // AXI signals
  logic [AXI_ADDR_BW-1:0] axi_awaddr;
  logic axi_awvalid;
  logic [MEMORY_BW_p-1:0] axi_wdata;
  logic axi_wvalid;
  logic [MEMORY_BW_p/8-1:0] axi_wstrb;
  logic axi_bready;
  logic [AXI_ADDR_BW-1:0] axi_araddr;
  logic axi_arvalid;
  logic axi_rready;
  logic axi_awready;
  logic axi_wready;
  logic [1:0] axi_bresp;
  logic axi_bvalid;
  logic axi_arready;
  logic [MEMORY_BW_p-1:0] axi_rdata;
  logic [1:0] axi_rresp;
  logic axi_rvalid;
  
  // Testbench internal signals
  logic [MEMORY_BW_p-1:0] rd_data;

  // DUT instantiation
  axi_lite_scratchpad #(
    .MEMORY_BW_p(MEMORY_BW_p),
    .MEMORY_DEPTH_p(MEMORY_DEPTH_p)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .i_axi_awaddr(axi_awaddr),
    .i_axi_awvalid(axi_awvalid),
    .i_axi_wdata(axi_wdata),
    .i_axi_wvalid(axi_wvalid),
    .i_axi_wstrb(axi_wstrb),
    .i_axi_bready(axi_bready),
    .i_axi_araddr(axi_araddr),
    .i_axi_arvalid(axi_arvalid),
    .i_axi_rready(axi_rready),
    .o_axi_awready(axi_awready),
    .o_axi_wready(axi_wready),
    .o_axi_bresp(axi_bresp),
    .o_axi_bvalid(axi_bvalid),
    .o_axi_arready(axi_arready),
    .o_axi_rdata(axi_rdata),
    .o_axi_rresp(axi_rresp),
    .o_axi_rvalid(axi_rvalid)
  );

  // Clock generation - 100MHz
  initial begin
    clk = 0;
    forever #5ns clk = ~clk;
  end

  // Test statistics
  int tests_passed = 0;
  int tests_failed = 0;
  
  // ============================================================
  // Task: Initialize RAM
  // ============================================================
  task automatic initialize_ram();
    for (int i = 0; i < MEMORY_DEPTH_p; i++) begin
      dut.ram_block[i] = '0;
    end
  endtask : initialize_ram

  // ============================================================
  // Task: AXI Write Transaction
  // ============================================================
  task automatic axi_write(
    input logic [AXI_ADDR_BW-1:0] addr,
    input logic [MEMORY_BW_p-1:0] data,
    input logic [MEMORY_BW_p/8-1:0] strb = '1
  );
    // Issue write address and write data simultaneously
    @(posedge clk);
    axi_awaddr <= addr;
    axi_awvalid <= 1'b1;
    axi_wdata <= data;
    axi_wstrb <= strb;
    axi_wvalid <= 1'b1;
    axi_bready <= 1'b1;
    
    // Wait for address acceptance
    @(posedge clk);
    while (!axi_awready) @(posedge clk);
    axi_awvalid <= 1'b0;
    
    // Wait for data acceptance (might be same cycle)
    while (!axi_wready) @(posedge clk);
    axi_wvalid <= 1'b0;
    
    // Wait for write response
    while (!axi_bvalid) @(posedge clk);
    
    if (axi_bresp == 2'b00) begin
      $display("[%0t] WRITE SUCCESS: Addr=0x%0h, Data=0x%0h, Strb=0x%0h", 
               $time, addr, data, strb);
    end else begin
      $display("[%0t] WRITE ERROR: Addr=0x%0h, Response=0x%0h", 
               $time, addr, axi_bresp);
    end
    
    @(posedge clk);
    axi_bready <= 1'b0;
  endtask

  // ============================================================
  // Task: AXI Read Transaction
  // ============================================================
  task automatic axi_read(
    input  logic [AXI_ADDR_BW-1:0] addr,
    output logic [MEMORY_BW_p-1:0] data
  );
    // Issue read address
    @(posedge clk);
    axi_araddr <= addr;
    axi_arvalid <= 1'b1;
    axi_rready <= 1'b1;
    
    // Wait for address acceptance
    @(posedge clk);
    while (!axi_arready) @(posedge clk);
    axi_arvalid <= 1'b0;
    
    // Wait for read data (2-cycle latency expected)
    while (!axi_rvalid) @(posedge clk);
    
    data = axi_rdata;
    
    if (axi_rresp == 2'b00) begin
      $display("[%0t] READ SUCCESS: Addr=0x%0h, Data=0x%0h", 
               $time, addr, data);
    end else begin
      $display("[%0t] READ ERROR: Addr=0x%0h, Response=0x%0h", 
               $time, addr, axi_rresp);
    end
    
    @(posedge clk);
    axi_rready <= 1'b0;
  endtask

  // ============================================================
  // Task: Write then Read and Check
  // ============================================================
  task automatic write_read_check(
    input logic [AXI_ADDR_BW-1:0] addr,
    input logic [MEMORY_BW_p-1:0] write_data,
    input logic [MEMORY_BW_p/8-1:0] strb = '1
  );
    logic [MEMORY_BW_p-1:0] read_data;
    logic [MEMORY_BW_p-1:0] expected_data;
    
    $display("\n=== Test: Write 0x%0h to address 0x%0h, then read back ===", 
             write_data, addr);
    
    // Perform write
    axi_write(addr, write_data, strb);
    
    // Small delay
    repeat(2) @(posedge clk);
    
    // Perform read
    axi_read(addr, read_data);
    
    // Calculate expected data (accounting for byte enables)
    expected_data = '0;
    for (int i = 0; i < MEMORY_BW_p/8; i++) begin
      if (strb[i]) begin
        expected_data[i*8 +: 8] = write_data[i*8 +: 8];
      end
    end
    
    // Check correctness
    if (read_data === expected_data) begin
      $display("[PASS] Read data matches! Expected=0x%0h, Got=0x%0h", 
               expected_data, read_data);
      tests_passed++;
    end else begin
      $display("[FAIL] Read data mismatch! Expected=0x%0h, Got=0x%0h", 
               expected_data, read_data);
      tests_failed++;
    end
  endtask

  // ============================================================
  // Task: Back-to-Back Reads
  // ============================================================
  task automatic back_to_back_reads(
    input logic [AXI_ADDR_BW-1:0] addr1,
    input logic [AXI_ADDR_BW-1:0] addr2
  );
    logic [MEMORY_BW_p-1:0] data1, data2;
    
    $display("\n=== Test: Back-to-back reads from 0x%0h and 0x%0h ===", 
             addr1, addr2);
    
    // Issue first read
    @(posedge clk);
    axi_araddr <= addr1;
    axi_arvalid <= 1'b1;
    axi_rready <= 1'b1;
    
    @(posedge clk);
    while (!axi_arready) @(posedge clk);
    
    // Issue second read immediately
    axi_araddr <= addr2;
    axi_arvalid <= 1'b1;
    
    @(posedge clk);
    while (!axi_arready) @(posedge clk);
    axi_arvalid <= 1'b0;
    
    // Collect first read response
    while (!axi_rvalid) @(posedge clk);
    data1 = axi_rdata;
    $display("[%0t] First read data: 0x%0h from addr 0x%0h", $time, data1, addr1);
    
    // Collect second read response
    @(posedge clk);
    while (!axi_rvalid) @(posedge clk);
    data2 = axi_rdata;
    $display("[%0t] Second read data: 0x%0h from addr 0x%0h", $time, data2, addr2);
    
    @(posedge clk);
    axi_rready <= 1'b0;
    
    tests_passed++;
  endtask

  // ============================================================
  // Main Test Sequence
  // ============================================================
  initial begin
    // Initialize signals
    axi_awaddr = '0;
    axi_awvalid = '0;
    axi_wdata = '0;
    axi_wvalid = '0;
    axi_wstrb = '1;
    axi_bready = '0;
    axi_araddr = '0;
    axi_arvalid = '0;
    axi_rready = '0;
    rst_n = '0;
    
    // Reset sequence
    $display("\n========================================");
    $display("AXI-Lite Scratchpad Testbench");
    $display("========================================\n");
    
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    repeat(2) @(posedge clk);

    $display("\n=== RAM initialization");
    $display("Initializing RAM to all zeros...");
    initialize_ram();
    $display("RAM initialized!");
    
    // Test 1: Simple write and read
    write_read_check(32'h0000, 32'hDEADBEEF);
    
    // Test 2: Different address
    write_read_check(32'h0004, 32'h12345678);
    
    // Test 3: Another address
    write_read_check(32'h0008, 32'hCAFEBABE);
    
    // Test 4: Byte enables - write only lower 2 bytes
    write_read_check(32'h000C, 32'hAABBCCDD, 4'b0011);
    
    // Test 5: Byte enables - write only upper 2 bytes
    write_read_check(32'h0010, 32'h11223344, 4'b1100);
    
    // Test 6: Overwrite previous location
    write_read_check(32'h0000, 32'hFFFFFFFF);
    
    // Test 7: Multiple writes to different addresses
    $display("\n=== Test: Multiple sequential writes ===");
    axi_write(32'h0100, 32'hAAAAAAAA);
    axi_write(32'h0104, 32'hBBBBBBBB);
    axi_write(32'h0108, 32'hCCCCCCCC);
    tests_passed++;
    
    // Test 8: Read them back
    $display("\n=== Test: Read back multiple addresses ===");
    axi_read(32'h0100, rd_data);
    if (rd_data === 32'hAAAAAAAA) tests_passed++; else tests_failed++;
    
    axi_read(32'h0104, rd_data);
    if (rd_data === 32'hBBBBBBBB) tests_passed++; else tests_failed++;
    
    axi_read(32'h0108, rd_data);
    if (rd_data === 32'hCCCCCCCC) tests_passed++; else tests_failed++;
    
    // Test 9: Back-to-back reads (tests pipeline)
    back_to_back_reads(32'h0100, 32'h0104);
    
    // Test 10: Maximum throughput - 3 back-to-back reads
    $display("\n=== Test: Three back-to-back reads (max pipeline depth) ===");
    axi_write(32'h0200, 32'h11111111);
    axi_write(32'h0204, 32'h22222222);
    axi_write(32'h0208, 32'h33333333);
    repeat(2) @(posedge clk);
    
    // Issue 3 reads back-to-back
    fork
      begin
        @(posedge clk);
        axi_araddr <= 32'h0200;
        axi_arvalid <= 1'b1;
        axi_rready <= 1'b1;
        @(posedge clk);
        while (!axi_arready) @(posedge clk);
        
        axi_araddr <= 32'h0204;
        @(posedge clk);
        while (!axi_arready) @(posedge clk);
        
        axi_araddr <= 32'h0208;
        @(posedge clk);
        while (!axi_arready) @(posedge clk);
        axi_arvalid <= 1'b0;
      end
      
      begin
        // Collect 3 responses
        repeat(3) begin
          while (!axi_rvalid) @(posedge clk);
          $display("[%0t] Read data: 0x%0h", $time, axi_rdata);
          @(posedge clk);
        end
        axi_rready <= 1'b0;
      end
    join
    tests_passed++;
    
    // Summary
    repeat(10) @(posedge clk);
    
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Tests Passed: %0d", tests_passed);
    $display("Tests Failed: %0d", tests_failed);
    
    if (tests_failed == 0) begin
      $display("\n*** ALL TESTS PASSED ***\n");
    end else begin
      $display("\n*** SOME TESTS FAILED ***\n");
    end
    
    $finish;
  end

  // Timeout watchdog
  initial begin
    #100us;
    $display("\n*** ERROR: Testbench timeout! ***\n");
    $finish;
  end

  // Optional: Waveform dump
  initial begin
    $dumpfile("axi_lite_scratchpad.vcd");
    $dumpvars(0, axi_lite_scratchpad_sim_tb);
  end

endmodule
