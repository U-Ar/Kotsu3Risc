module csr(input  logic        clk,
           input  logic        reset,
           input  logic [63:0] pc,
           input  logic [11:0] WA,
           input  logic [63:0] WD,
           input  logic        csrwrite, exception, mret, sret, interrupt,
           input  logic [63:0] tval,
           input  logic [62:0] causecode,
           output logic [63:0] RD, epc, tvec,
           output logic [1:0]  mode,
           output logic        deleg);
    
    logic [63:0] mvendorid, marchid, mimpid, mhartid, mstatus, misa, medeleg,
                 mideleg, mie, mtvec, mcounteren, mscratch, mepc, mcause,
                 mtval, mip;
    logic [63:0] mcycle, minstret, mcountinhibit, tselect, tdata1, tdata2, tdata3,
                 dcsr, dpc, dscratch0, dscratch1;
    logic [63:0] sedeleg, sideleg, sie, stvec, scounteren, sscratch, sepc,
                 scause, stval, sip, satp;
    logic [63:0] fflags, frm, fcsr, cycle, time_csr, instret;
    
    //epc, tvec
    assign epc  = ((!mret)&(deleg|sret)) ? sepc : mepc;
    logic [63:0] mtvectmp, stvectmp;
    mux2 #(64) muxmtvec({mtvec[63:2],2'b0},{mtvec[63:2],2'b0}+(causecode<<2),mtvec[0],mtvectmp);
    mux2 #(64) muxstvec({stvec[63:2],2'b0},{stvec[63:2],2'b0}+(causecode<<2),stvec[0],stvectmp);
    mux2 #(64) muxtvec(mtvectmp,stvectmp,deleg,tvec);

    //delegation
    assign deleg = (interrupt) ? mideleg[causecode] : medeleg[causecode];

    //モードレジスタ
    logic [1:0] nextmode;
    always_comb begin 
        if (exception&(!deleg)) nextmode = 2'b00;
        else if (exception&(deleg)) nextmode = 2'b01;
        else if (mret) nextmode = mstatus[12:11]; //mstatus.MPP
        else if (sret) nextmode = {1'b0, mstatus[8]}; //mstatus.SPP
        else nextmode = mode;
    end
    always_ff @ (posedge clk) begin 
        mode <= nextmode;
    end

    //mstatus
    logic [63:0] mstatex, mstatret, sstatex, sstatret;
    //                                 MPP=mode             MPIE=MIE                  MIE=0
    assign mstatex  = {mstatus[63:13], mode, mstatus[10:8], mstatus[3], mstatus[6:4], 1'b0, mstatus[2:0]};
    //                                MIE=MPIE
    assign mstatret = {mstatus[63:4], mstatus[7], mstatus[2:0]};
    //                                SPP=mode               SPIE=SIE                  SIE=0
    assign sstatex  = {mstatus[63:9], mode[0], mstatus[7:6], mstatus[1], mstatus[4:2], 1'b0, mstatus[0]};
    //                                SIE=SPIE
    assign sstatret = {mstatus[63:2], mstatus[7], mstatus[0]};

    //CSR読み出し
    always_comb begin
        case (WA) 
            //user csr
            12'h001: RD = fflags;
            12'h002: RD = frm;
            12'h003: RD = fcsr;
            12'hc00: RD = cycle;
            12'hc01: RD = time_csr;
            12'hc02: RD = instret;

            //supervisor csr
            12'h100: RD = mstatus; //sstatusのエイリアス
            12'h102: RD = sedeleg;
            12'h103: RD = sideleg;
            12'h104: RD = sie;
            12'h105: RD = stvec;
            12'h106: RD = scounteren;
            12'h140: RD = sscratch;
            12'h141: RD = sepc;
            12'h142: RD = scause;
            12'h143: RD = stval;
            12'h144: RD = sip;
            12'h180: RD = satp;

            //machine csr
            12'hf11: RD = mvendorid;
            12'hf12: RD = marchid;
            12'hf13: RD = mimpid;
            12'hf14: RD = mhartid;

            12'h300: RD = mstatus;
            12'h301: RD = misa;
            12'h302: RD = medeleg;
            12'h303: RD = mideleg;
            12'h304: RD = mie;
            12'h305: RD = mtvec;
            12'h306: RD = mcounteren;

            12'h340: RD = mscratch;
            12'h341: RD = mepc;
            12'h342: RD = mcause;
            12'h343: RD = mtval;
            12'h344: RD = mip;

            //counter/timer/debug
            12'hb00: RD = cycle;
            12'hb02: RD = minstret;
            12'h320: RD = mcountinhibit;
            12'h7a0: RD = tselect;
            12'h7a1: RD = tdata1;
            12'h7a2: RD = tdata2;
            12'h7a3: RD = tdata3;
            12'h7b0: RD = dcsr;
            12'h7b1: RD = dpc;
            12'h7b2: RD = dscratch0;
            12'h7b3: RD = dscratch1;
        endcase
    end

    //CSR書き込み
    always_ff @ (posedge clk) begin 
        if (csrwrite) begin
            case (WA)
                //user csr
                12'h001: fflags     <= WD;
                12'h002: frm        <= WD;
                12'h003: fcsr       <= WD;
                12'hc00: cycle      <= WD;
                12'hc01: time_csr   <= WD;
                12'hc02: instret    <= WD;
                //supervisor csr
                12'h100: mstatus    <= WD; //sstatusのエイリアス
                12'h102: sedeleg    <= WD;
                12'h103: sideleg    <= WD;
                12'h104: sie        <= WD;
                12'h105: stvec      <= WD;
                12'h106: scounteren <= WD;
                12'h140: sscratch   <= WD;
                12'h141: sepc       <= WD;
                12'h142: scause     <= WD;
                12'h143: stval      <= WD;
                12'h144: sip        <= WD;
                12'h180: satp       <= WD;
                //machine csr
                12'hf11: mvendorid  <= WD;
                12'hf12: marchid    <= WD;
                12'hf13: mimpid     <= WD;
                12'hf14: mhartid    <= WD;
                12'h300: mstatus    <= WD;
                12'h301: misa       <= WD;
                12'h302: medeleg    <= WD;
                12'h303: mideleg    <= WD;
                12'h304: mie        <= WD;
                12'h305: mtvec      <= WD;
                12'h306: mcounteren <= WD;
                12'h340: mscratch   <= WD;
                12'h341: mepc       <= WD;
                12'h342: mcause     <= WD;
                12'h343: mtval      <= WD;
                12'h344: mip        <= WD;
                //timer/debug
                12'hb00: mcycle     <= WD;
                12'hb02: minstret   <= WD;
                12'h320: mcountinhibit <= WD;
                12'h7a0: tselect    <= WD;
                12'h7a1: tdata1     <= WD;
                12'h7a2: tdata2     <= WD;
                12'h7a3: tdata3     <= WD;
                12'h7b0: dcsr       <= WD;
                12'h7b1: dpc        <= WD;
                12'h7b2: dscratch0  <= WD;
                12'h7b3: dscratch1  <= WD;
            endcase 
        end
        else if (exception&(!deleg)) begin 
            mtval <= tval;
            mepc <= pc;
            mcause <= {interrupt, causecode};
            mstatus <= mstatex;
        end
        else if (exception&deleg) begin 
            stval <= tval;
            sepc <= pc;
            scause <= {interrupt, causecode};
            mstatus <= sstatex;
        end
        else if (mret) begin 
            mstatus <= mstatret;
        end
        else if (sret) begin 
            mstatus <= sstatret;
        end
    end
endmodule