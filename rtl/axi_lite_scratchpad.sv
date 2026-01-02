// AXI4-Lite module used to access SRAM.
// Bit-width can be either 32- or 64-bit
// Depth can be whatever you prefer.
//
// Example 4k scratchpad:
// MEMORY_BW_p = 32, MEMORY_DEPTH_p = 1024 32-bits = 4 bytes * 1024 rows = 4K
//
// ORDERING BEHAVIOR:
// This slave does not guarantee read-after-write ordering.
// Masters must wait for write response (BVALID) before 
// issuing reads to the same address if they require 
// updated data.
//
// This is compliant with AXI4-Lite specification which
// does not mandate ordering between read and write channels (but still it's annoying).

module axi_lite_scratchpad #(
  parameter int unsigned MEMORY_BW_p = 32,     // Can be either 32- or 64-bit
  parameter int unsigned MEMORY_DEPTH_p = 1024 // 4k SRAM by default
) (
  input logic  clk,
  input logic  rst_n,
  input logic [$clog2((MEMORY_BW_p/8)*(MEMORY_DEPTH_p))-1:0] i_axi_awaddr,
  input logic  i_axi_awvalid,
  input logic [MEMORY_BW_p-1:0] i_axi_wdata,
  input logic i_axi_wvalid,
  input logic [MEMORY_BW_p/8-1:0] i_axi_wstrb,
  input logic i_axi_bready,
  input logic [$clog2((MEMORY_BW_p/8)*(MEMORY_DEPTH_p))-1:0] i_axi_araddr,
  input logic i_axi_arvalid,
  input logic i_axi_rready,
  output logic o_axi_awready,
  output logic o_axi_wready,
  output logic [1:0] o_axi_bresp,
  output logic o_axi_bvalid,
  output logic o_axi_arready,
  output logic [MEMORY_BW_p-1:0] o_axi_rdata,
  output logic [1:0] o_axi_rresp,
  output logic o_axi_rvalid
);

  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_EXOKAY = 2'b01;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam logic [1:0] RESP_DECERR = 2'b11;

  localparam int unsigned AXI_ADDR_BW_p  = $clog2((MEMORY_BW_p/8)*(MEMORY_DEPTH_p));
  localparam int unsigned AXI_DATA_BW_p  = MEMORY_BW_p;
  localparam int unsigned AXI_WSTRB_BW_p = MEMORY_BW_p/8;
  localparam int unsigned AXI_ADDR_ALIGNMENT_p = $clog2((MEMORY_BW_p/8));
 
  logic [MEMORY_BW_p-1:0] ram_block [MEMORY_DEPTH_p];
  logic s_ram_we;

  // --------------------------------------------------------------
  // Write address, write data and write wresponse
  // --------------------------------------------------------------
  logic [1:0]  c_axi_wresp;
  logic [AXI_WSTRB_BW_p-1:0] c_axi_wstrb;
  logic [AXI_DATA_BW_p-1:0]   c_axi_wdata;
  logic s_axi_wdata_buf_used;
  logic [AXI_DATA_BW_p-1:0]   s_axi_wdata_buf;
  logic [AXI_WSTRB_BW_p-1:0] s_axi_wstrb_buf;
  logic [1:0]  s_axi_bresp;
  logic [AXI_ADDR_BW_p-1:0] s_axi_awaddr_buf;
  logic [AXI_ADDR_BW_p-1:0] c_axi_awaddr;
  logic s_axi_awaddr_buf_used;
  logic s_axi_awvalid;
  logic s_axi_wvalid;
  // Internal signals
  logic s_axi_bvalid;
  logic s_axi_awready;
  logic s_axi_wready;
 
  // We want to stall the address write if either we received write request without write data
  // or if the write address buffer is full and master is stalling write response channel
  assign o_axi_awready = !s_axi_awaddr_buf_used & s_axi_awvalid;

  // We want to stall the data write if either we received write data without a write request
  // or if the write data buffer is full and master is stalling write response channel
  assign o_axi_wready  = !s_axi_wdata_buf_used & s_axi_wvalid;
  
  // Simple address decoder
  logic write_addr_valid;
  assign write_addr_valid = (c_axi_awaddr[AXI_ADDR_BW_p-1:AXI_ADDR_ALIGNMENT_p] < MEMORY_DEPTH_p);

  logic write_response_stalled;
  logic valid_write_address;
  logic valid_write_data;

  assign write_response_stalled = o_axi_bvalid & ~i_axi_bready;
  assign valid_write_address = s_axi_awaddr_buf_used | (i_axi_awvalid & o_axi_awready);
  assign valid_write_data = s_axi_wdata_buf_used | (i_axi_wvalid & o_axi_wready);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_awvalid <= 1'b0;
      s_axi_awaddr_buf_used <= 1'b0;
    end else begin
      s_axi_awvalid <= 1'b1;
      // When master is stalling on the response channel or if we didn't receive
      // write data, we need to buffer the address
      if (i_axi_awvalid && o_axi_awready && (write_response_stalled || !valid_write_data)) begin
        s_axi_awaddr_buf <= i_axi_awaddr;
        s_axi_awaddr_buf_used <= 1'b1;
      end else if (s_axi_awaddr_buf_used && valid_write_data && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_awaddr_buf_used <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_wdata_buf_used <= 1'b0;
      s_axi_wvalid <= 1'b0;
    end else begin
      s_axi_wvalid <= 1'b1;
      // We want to fill the buffer if either we're getting a response stall, or we 
      // get a write data without a write address
      if (i_axi_wvalid && o_axi_wready && (write_response_stalled || !valid_write_address)) begin
        s_axi_wdata_buf <= i_axi_wdata;
        s_axi_wstrb_buf <= i_axi_wstrb;
        s_axi_wdata_buf_used <= 1'b1;
      end else if (s_axi_wdata_buf_used && valid_write_address && (!o_axi_bvalid || i_axi_bready)) begin
        s_axi_wdata_buf_used <= 1'b0;
      end
    end
  end

  // Write to RAM, individual byte-enables
  generate
    for (genvar i = 0; i < MEMORY_BW_p/8; i++) begin : ram_write_byte_en
      always_ff @(posedge clk) begin
        if (s_ram_we && c_axi_wstrb[i]) begin
          ram_block[c_axi_awaddr[AXI_ADDR_BW_p-1:AXI_ADDR_ALIGNMENT_p]][i*8 +:8] <= c_axi_wdata[i*8 +: 8];
        end
      end
    end
  endgenerate

  // Muxes to select write address and write data either from the buffer or from the AXI bus
  assign c_axi_awaddr = s_axi_awaddr_buf_used ? s_axi_awaddr_buf : i_axi_awaddr;
  assign c_axi_wdata  = s_axi_wdata_buf_used  ? s_axi_wdata_buf : i_axi_wdata;
  assign c_axi_wstrb  = s_axi_wdata_buf_used  ? s_axi_wstrb_buf : i_axi_wstrb;

  // Generate a response
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_bvalid <= 1'b0;
      s_ram_we <= 1'b0;
    end else begin
      s_ram_we <= 1'b0;
      // If there is write address and write data in the buffer
      if (valid_write_address && valid_write_data && (!o_axi_bvalid || i_axi_bready)) begin
        if (write_addr_valid) begin 
          s_ram_we <= 1'b1;
          s_axi_bresp <= RESP_OKAY;
        end else begin
          s_axi_bresp <= RESP_SLVERR;
        end
        s_axi_bvalid <= 1'b1;
      end else if (o_axi_bvalid && i_axi_bready && !(valid_write_address && valid_write_data)) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end
  
  // Assign intermediate signals to outputs 
  assign o_axi_bresp = s_axi_bresp;
  assign o_axi_bvalid = s_axi_bvalid;
  
  // --------------------------------------------------------------
  // Read address and read response
  // --------------------------------------------------------------
  logic s_axi_rvalid;
  logic [AXI_DATA_BW_p-1:0] s_axi_rdata;
  logic [1:0] s_axi_rresp;
  logic s_axi_arready;

  // Read address buffer
  logic [AXI_ADDR_BW_p-1:0] s_araddr_buf;
  logic s_araddr_buf_used;
  logic [AXI_ADDR_BW_p-1:0] c_axi_araddr;

  // Address buffer management
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_araddr_buf_used <= 1'b0;
      s_axi_arready <= 1'b0;
    end else begin
      s_axi_arready <= 1'b1;

      // Fill buffer when response is stalled
      if (i_axi_arvalid && o_axi_arready && o_axi_rvalid && !i_axi_rready) begin
        s_araddr_buf <= i_axi_araddr;
        s_araddr_buf_used <= 1'b1;
      end 
      // Clear buffer when address is consumed
      else if (s_araddr_buf_used && (!o_axi_rvalid || i_axi_rready)) begin
        s_araddr_buf_used <= 1'b0;
      end
    end
  end

  // Mux to select address 
  assign c_axi_araddr = s_araddr_buf_used ? s_araddr_buf : i_axi_araddr;

  // Ready signal blocks when buffer full
  assign o_axi_arready = !s_araddr_buf_used & s_axi_arready;

  // Response generation
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      s_axi_rvalid <= 1'b0;
    end else begin
      // Generate response when address is available (buffer or direct)
      if ((s_araddr_buf_used || (i_axi_arvalid && o_axi_arready)) && (!o_axi_rvalid || i_axi_rready)) begin
        if (c_axi_araddr[AXI_ADDR_BW_p-1:AXI_ADDR_ALIGNMENT_p] < MEMORY_DEPTH_p) begin
          s_axi_rdata <= ram_block[c_axi_araddr[AXI_ADDR_BW_p-1:AXI_ADDR_ALIGNMENT_p]];
          s_axi_rresp <= RESP_OKAY;
        end else begin
          s_axi_rdata <= 'hdeaddead;
          s_axi_rresp <= RESP_SLVERR;
        end
        s_axi_rvalid <= 1'b1;
      // Clear response when handshake completes and no new transaction
      end else if (o_axi_rvalid && i_axi_rready && !s_araddr_buf_used && !(i_axi_arvalid && o_axi_arready)) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  assign o_axi_rdata = s_axi_rdata;
  assign o_axi_rresp = s_axi_rresp;
  assign o_axi_rvalid = s_axi_rvalid;

endmodule : axi_lite_scratchpad
