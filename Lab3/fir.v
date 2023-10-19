module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,

    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,

    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready,

    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
// write your code here!

    // assign awready = awvalid && (awaddr[7:4] >= 2);
    // assign wready =  wvalid && (awaddr[7:4] >= 2);
    reg arready_r, rvalid_r, awready_r, wready_r;
    reg [31:0] rdata_r;
    wire [7:0] awaddr_20, araddr_20;
    reg [7:0] tap_ptr, data_ptr;
    reg tap_ro;
    reg [31:0] ss_tdata_r;

    reg ap_start_r, ap_done_r, ap_idle_r;
    wire ap_start,ap_done,ap_idle;
    assign ap_start = ap_start_r;
    assign ap_done = ap_done_r;
    assign ap_idle = ap_idle_r;

    assign awaddr_20 = awaddr[7:0] - 8'h20;
    assign araddr_20 = araddr[7:0] - 8'h20;
    assign tap_EN = 1;
    reg data_wen;

    assign tap_WE = (wvalid && wready_r && awaddr[7:4]>1)? 4'b1111 : 4'b0000;
    assign tap_Di = (wvalid && wready_r)? wdata : (rready && rvalid_r)? rdata : 1'bX;
    assign tap_A = (tap_ro)? tap_ptr : (wvalid && wready_r)? {awaddr_20} : (rready)? {araddr_20} : 1'bX;
    assign rdata = (!rvalid_r)? 1'bX : (araddr[7:0] == 8'b0)? {29'b0,ap_idle,ap_done,ap_start} : tap_Do; 

    assign data_EN = 1;
    reg data_setting;
    assign data_WE = (data_wen || data_setting)? 4'b1111 : 4'b0000;
    assign data_Di = (data_wen)? ss_tdata : (data_setting)? 32'b0 : 1'bX;
    assign data_A = data_ptr;
    

    //assign data_A = data_ptr;
    //assign rdata = tap_Do;
    reg ss_tready_r, sm_tvalid_r,sm_tlast_r;
    reg signed [31:0] sm_tdata_r;
    
    assign awready = awready_r;
    assign wready = wready_r;
    assign arready = arready_r;
    assign ss_tready = ss_tready_r;
    assign sm_tdata = sm_tdata_r;
    assign sm_tvalid = sm_tvalid_r;
    assign sm_tlast = sm_tlast_r;
    assign rvalid = rvalid_r;
    //assign rdata = rdata_r;
    reg weird;
    reg signed [31:0] mac_part;

    //assign sm_tdata = mac_part + $signed(ss_tdata_r) * $signed(tap_Do);


    reg [2:0] state;
    reg [3:0] counter;
    reg [7:0] data_new;
    reg ss_tlast_real;

    wire signed [31:0] y;
    assign y = mac_part + $signed(tap_Do) * $signed(data_Do);
    reg data_reset;
    

    always@(posedge axis_clk or negedge axis_rst_n) begin 
        if (!axis_rst_n) begin 
            arready_r <= 1'b0;
            rdata_r <= 32'b0;
            rvalid_r <= 1'b0;
            awready_r <= 1'b0;
            wready_r <= 1'b0;
            weird <= 1'b0;
            state <= 3'b0;
            ap_start_r <= 1'b0;
            ap_done_r <= 1'b0;
            ap_idle_r <= 1'b1;
            ss_tready_r <= 1'b0;
            sm_tdata_r <= 32'b0;
            sm_tvalid_r <= 1'b0;
            sm_tlast_r <= 1'b0;
            tap_ptr <= 8'b0;
            data_ptr <= 8'b0;   
            tap_ro <= 1'b0;
            ss_tdata_r <= 32'b0;
            counter <= 4'b0;
            mac_part <= 32'b0;
            data_wen <= 1'b0;
            data_setting <= 1'b0;
            data_new <= 8'b0;
            ss_tlast_real <= 1'b0;
            data_reset <= 1'b0;
            

        end
        else begin
            sm_tlast_r <= 1'b0;
            if (awvalid && wvalid) begin
                wready_r <= 1'b1;
                awready_r <= 1'b1;

                if (awaddr[7:0]==8'b0 && (state == 3'b0 || state == 3'd7)) begin 
                    if (wdata[0]) ap_start_r <= 1;
                end 

            end
            // else begin 
            //     wready_r <= 1'b0;
            //     awready_r <= 1'b0;
            // end

            if (arvalid && rready) begin
                if (!weird) begin 
                rvalid_r <= 1'b1;
                arready_r <= 1'b1;
                end

                else begin 
                    rvalid_r <= 1'b0;
                end 

                weird <= weird? 1'b0 : 1'b1;
            end

            //if (rvalid_r && arvalid) rdata_r <= tap_Do;
            // else begin 
            //     rvalid_r <= 1'b0;
            //     arready_r <= 1'b0;
            // end
            case(state)
                3'b0 : begin 
                    //ss_tready_r <= 1'b0;
                    if (data_ptr == 8'h28) begin 
                        data_setting <= 1'b0;
                        data_reset <= 1'b1;
                    end
                    else begin 
                        data_setting <= 1'b1;
                        data_ptr <= data_setting? data_ptr + 4 : 8'b0;
                    end
                    

                    if (ap_start_r && data_reset) begin 
                        ss_tready_r <= 1'b1;
                        tap_ptr <= 8'b0;
                        data_ptr <= 8'b0;         
                        tap_ro <= 1'b1;  
                        mac_part <= 32'b0;
                        data_wen <= 1'b1;
                        state <= 3'd1;
                        ap_idle_r <= 1'b0;
                        ss_tlast_real <= 1'b0;  
                        data_reset <= 1'b0;
                        data_new <= 8'b0;
                        ap_done_r <= 1'b0;
                        
                    end 
                end
                3'b1 : begin
                    tap_ptr <= 8'b0;
                    data_ptr <= (data_new == 8'h28)? 8'b0 : data_new + 4;
                    ap_start_r <= 1'b0;
                    ss_tready_r <= 1'b0;
                    //ss_tdata_r <= ss_tdata;
                    //counter <= (counter == 4'b1111)? 4'b1111 : counter + 1;
                    data_wen <= 1'b0;
                    state <= 3'd2;
                end
                3'd2 : begin

                    tap_ptr <= tap_ptr + 4;
                    data_ptr <= (data_ptr == 8'h28)? 8'b0 : data_ptr + 4;
                    if (tap_ptr > 8'h0) begin 
                        mac_part <= y;
                    end
                    state <= (tap_ptr == 8'h2c)? 3'd3 : 3'd2;
   
                end
                3'd3 : begin 
                    sm_tvalid_r <= 1'b1;
                    sm_tdata_r <= mac_part;
                    //data_ptr <= 8'b0;
                    state <= 3'd4;
                end
                3'd4 : begin 
                    sm_tvalid_r <= 1'b0;


                    if (!ss_tlast_real) begin 
                        data_new <= (data_new == 8'h28)? 8'b0 : data_new + 4;
                        data_ptr <= (data_new == 8'h28)? 8'b0 : data_new + 4;
                        ss_tready_r <= 1'b1;
                        mac_part <= 32'b0;
                        data_wen <= 1'b1;
                        if (ss_tlast) ss_tlast_real <= 1'b1;
                        state <= 3'd1;
                    end
                    else state <= 3'd5;
                end
                3'd5 : begin 
                    ap_done_r <= 1'b1;
                    ap_idle_r <= 1'b1;
                    state <= 3'd6;
                end
                3'd6 : begin 
                    state <= 3'd7;
                end
                3'd7 : begin 
                    state <= 3'b0;
                    if (ap_start_r) begin 
                        ap_done_r <= 1'b0;
                        ap_idle_r <= 1'b0;
                        data_ptr <= 8'b0;   

                    end
                end
                
            endcase

        end
    end


endmodule