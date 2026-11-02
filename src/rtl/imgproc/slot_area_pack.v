`timescale 1ns/1ps

module slot_area_pack (
    input  wire [127:0] I_area32,
    output wire [95:0]  O_area24
);

    assign O_area24 = { I_area32[119:96],
                        I_area32[87:64],
                        I_area32[55:32],
                        I_area32[23:0]  };

endmodule
