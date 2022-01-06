const std = @import("std");
const mem = std.mem;
const control_code = std.ascii.control_code;

///! nL, nH, etc. means n lower bits and n higher bits. For passing
///! 16 bit integers

/// Moves the print position to the next horizontal tab position.
pub const HT = control_code.TAB;
/// Prints the data in the print buffer and feeds one line based on
/// the current line spacing.
pub const LF = control_code.LF;
/// Prints the data in the print buffer collectively and returns to
/// standard mode.
pub const FF = control_code.FF;
/// When automatic line feed is enabled, this command functions the
/// same as LF; when automatic line feed is disabled, this command is ignored.
pub const CR = control_code.CR;

pub const ESC = control_code.ESC;
pub const FS = control_code.FS;
pub const GS = control_code.GS;
pub const SP = 0x20;

/// In page mode, deletes all the print data in the current printable area.
pub const cancel_page = "\x18";

// real-time status transmission not implemented yet
// Real-time request not implemented yet
// Generate pulse at real-time not implemented yet

/// In page mode, prints all buffered data in the printing area collectively.
pub const print_page = [_]u8{ ESC, FF };

/// Sets the character spacing for the right side of the character to
/// [ n horizontal or vertical motion units].
pub fn setRightSideCharacterSpacing(spaces: u8) [3]u8 {
    return .{ ESC, SP, spaces };
}

/// Selects print mode(s)
pub fn printMode(options: print_mode_options) [3]u8 {
    var n = 0;
    if (options.font_select) {
        n |= 0x01;
    }
    if (options.emphasized) {
        n |= 0x08;
    }
    if (options.double_height) {
        n |= 0x10;
    }
    if (options.double_width) {
        n |= 0x20;
    }
    if (options.undeline) {
        n |= 0x80;
    }
    return .{ ESC, '!', n };
}

pub const print_mode_options = struct {
    /// false = font A (12x24), true = font B (9x17)
    font_select: bool,
    emphasized: bool,
    double_height: bool,
    double_width: bool,
    undeline: bool,
};

/// Sets the distance from the beginning of the line to the position
/// at which subsequent characters are to be printed.
pub fn setPrintPosition(l: u8, h: u8) [4]u8 {
    return .{ ESC, '$', l, h };
}

// select user-defined character set not implemented yet
// define user-defined character set not implemented yet

// TODO: This needs to be reviewed, I may have misunderstood the manual
/// Caller is responsible for freeing returned memory
pub fn bitImageMode(allocator: mem.Allocator, mode: bit_image_mode, nl: u8, nh: u2, image_data: []const u8) ![]u8 {
    if (nl * nh == image_data.len) {
        return error.ImageLengthMismatch;
    }
    const wide = (mode == .single24 or mode == .double24);
    const image_length = nl * nh * (if (wide) 3 else 1);
    if (image_data.len != image_length) {
        return error.ImageLengthMismatch;
    }
    const preamble = [_]u8{ ESC, '*', mode, nl, nh };
    return mem.concat(allocator, u8, .{ preamble, image_data });
}

const bit_image_mode = enum(u8) {
    single8 = 0,
    double8 = 1,
    single24 = 32,
    double24 = 33,
};

/// Turns underline mode on or off
pub const underline = struct {
    pub const none = [_]u8{ ESC, '-', 0 };
    pub const one = [_]u8{ ESC, '-', 1 };
    pub const two = [_]u8{ ESC, '-', 2 };
};

pub const line_spacing = struct {
    /// Selects 1/ 6-inch line (approximately 4.23mm) spacing.
    pub const default = [_]u8{ ESC, '2' };

    /// Sets the line spacing to [ n ╳ vertical or horizontal motion
    /// unit] inches.
    pub fn custom(spacing: u8) [3]u8 {
        return .{ ESC, '3', spacing };
    }
};

/// Set peripheral device
pub const peripheral_device = struct {
    pub const disable = [_]u8{ ESC, '=', 0 };
    pub const enable = [_]u8{ ESC, '=', 1 };
};

// cancel user-defined characters not implemented yet

/// Clears the data in the print buffer and resets the printer mode to
/// the mode that was in effect when the power was turned on.
pub const initialize = [_]u8{ ESC, '@' };

/// Sets horizontal tab positions.
/// • positions specifies the column number for setting a horizontal
///   tab position from the beginning of the line.
/// You can set a maximum of 32 positions.
pub fn setHorizontalTabPositions(allocator: mem.Allocator, positions: []const u8) ![]u8 {
    if (positions.len > 32) {
        return error.TooManyTabPositions;
    }
    const preamble = [_]u8{ ESC, 'D' };
    return mem.concat(allocator, u8, preamble, positions, .{0});
}

/// Turns emphasized mode on or off
pub const emphasis = struct {
    pub const off = [_]u8{ ESC, 'E', 0 };
    pub const on = [_]u8{ ESC, 'E', 1 };
};

/// Turn on/off double-strike mode
pub const double_strike = struct {
    pub const off = [_]u8{ ESC, 'G', 0 };
    pub const on = [_]u8{ ESC, 'G', 1 };
};

/// Prints the data in the print buffer and feeds the paper [ n ╳
/// vertical or horizontal motion unit] inches.
pub fn printAndFeed(units: u8) [3]u8 {
    return [_]u8{ ESC, 'J', units };
}

/// Switches from standard mode to page mode.
/// • This command is enabled only when processed at the beginning of
///   a line in standard mode.
pub const page_mode = [_]u8{ ESC, 'L' };

/// Selects character fonts.
pub const character_font = struct {
    /// Character font A (12 × 24) selected.
    pub const font_a = [_]u8{ ESC, 'M', 0 };
    /// Character font B (9 × 17) selected.
    pub const font_b = [_]u8{ ESC, 'M', 1 };
};

/// Selects an international character set
pub const international_character_set = struct {
    pub const usa = [_]u8{ ESC, 'R', 0 };
    pub const france = [_]u8{ ESC, 'R', 1 };
    pub const germany = [_]u8{ ESC, 'R', 2 };
    pub const uk = [_]u8{ ESC, 'R', 3 };
    pub const denmark = [_]u8{ ESC, 'R', 4 };
    pub const sweden = [_]u8{ ESC, 'R', 5 };
    pub const italy = [_]u8{ ESC, 'R', 6 };
    pub const spain = [_]u8{ ESC, 'R', 7 };
    pub const japan = [_]u8{ ESC, 'R', 8 };
    pub const norway = [_]u8{ ESC, 'R', 9 };
    pub const denmark_ii = [_]u8{ ESC, 'R', 10 };
    pub const spain_ii = [_]u8{ ESC, 'R', 11 };
    pub const latin = [_]u8{ ESC, 'R', 12 };
    pub const korea = [_]u8{ ESC, 'R', 13 };
    /// The character sets for Slovenia/Croatia and China are
    /// supported only in the Simplified Chinese model.
    pub const slovenia_croatia = [_]u8{ ESC, 'R', 14 };
    pub const chinese = [_]u8{ ESC, 'R', 15 };
};

/// Switches from page mode to standard mode.
pub const standard_mode = [_]u8{ ESC, 'S' };

pub const page_mode_print_direction = struct {
    /// Starting position: upper left
    pub const left_to_right = [_]u8{ ESC, 'T', 0 };
    /// Starting position: lower left
    pub const bottom_to_top = [_]u8{ ESC, 'T', 1 };
    /// Starting position: lower right
    pub const right_to_left = [_]u8{ ESC, 'T', 2 };
    /// Starting position: upper right
    pub const top_to_bottom = [_]u8{ ESC, 'T', 3 };
};

/// Turns 90° clockwise rotation mode on/off
pub const clockwise_rotation_mode = struct {
    pub const off = [_]u8{ ESC, 'V', 0 };
    pub const on = [_]u8{ ESC, 'V', 1 };
};

/// • The horizontal starting position, vertical starting position,
///   printing area width, and printing area height are defined as x0,
///   y0, dx (inch), dy (inch), respectively.
/// Each setting for the printing area is calculated as follows:
/// x0 = [( xL + xH × 256) × (horizontal motion unit)]
/// y0 = [( yL + yH × 256) × (vertical motion unit)]
/// dx = [ dxL + dxH × 256] × (horizontal motion unit)]
/// dy = [ dyL + dyH × 256] × (vertical motion unit)]
pub fn setPageModeArea(xl: u8, xh: u8, yl: u8, yh: u8, dxl: u8, dxh: u8, dyl: u8, dyh: u8) [10]u8 {
    return [_]u8{ ESC, 'W', xl, xh, yl, yh, dxl, dxh, dyl, dyh };
}

/// Sets the print starting position based on the current position by
/// using the horizontal or vertical motion unit.
/// • This command sets the distance from the current position to [(
///   nL + nH ╳ 256) ╳ horizontal or vertical motion unit]
pub fn setRelativePrintPosition(nl: u8, nh: u8) [4]u8 {
    return [_]u8{ ESC, '\\', nl, nh };
}

/// Aligns all the data in one line to the specified position
pub const justification = struct {
    pub const left = [_]u8{ ESC, 'a', 0 };
    pub const center = [_]u8{ ESC, 'a', 1 };
    pub const right = [_]u8{ ESC, 'a', 2 };
};

// Select paper sensor(s) to output paper end signals not implemented
// yet

/// Selects the paper sensor(s) used to stop printing when a paper-end is detected
pub fn stopPrintingSensor(options: stop_printing_sensor) [4]u8 {
    var n = 0;
    if (options.paper_roll_end) {
        n |= 0x01;
    }
    if (options.paper_roll_near_end) {
        n |= 0x02;
    }
    return [_]u8{ ESC, 'c', '4', n };
}

pub const stop_printing_sensor = struct {
    paper_roll_end: bool,
    paper_roll_near_end: bool,
};

/// Enables or disables the panel buttons.
pub const panel_buttons = struct {
    pub const disable = [_]u8{ ESC, 'C', '5', 0 };
    pub const enable = [_]u8{ ESC, 'C', '5', 1 };
};

/// Prints the data in the print buffer and feeds n lines.
pub fn printAndFeedLines(lines: u8) [3]u8 {
    return [_]u8{ ESC, 'd', lines };
}

// Generate pulse not implemented yet

/// Select character code table.
pub const character_code_table = struct {
    ///[U.S.A.Standard Europe]
    pub const PC437 = [_]u8{ ESC, 't', 0 };
    pub const katakana = [_]u8{ ESC, 't', 1 };
    /// Multilingual
    pub const pc850 = [_]u8{ ESC, 't', 2 };
    /// Portuguese
    pub const pc860 = [_]u8{ ESC, 't', 3 };
    /// [Canadian French]
    pub const pc863 = [_]u8{ ESC, 't', 4 };
    /// Nodic
    pub const pc865 = [_]u8{ ESC, 't', 5 };
    pub const west_europe = [_]u8{ ESC, 't', 6 };
    pub const greek = [_]u8{ ESC, 't', 7 };
    pub const hebrew = [_]u8{ ESC, 't', 8 };
    /// East Europe
    pub const pc755 = [_]u8{ ESC, 't', 9 };
    pub const iran = [_]u8{ ESC, 't', 10 };
    pub const wpc1252 = [_]u8{ ESC, 't', 16 };
    /// cyrillic#2
    pub const pc866 = [_]u8{ ESC, 't', 17 };
    /// latin2
    pub const pc852 = [_]u8{ ESC, 't', 18 };
    pub const pc858 = [_]u8{ ESC, 't', 19 };
    pub const iranii = [_]u8{ ESC, 't', 20 };
    pub const latvian = [_]u8{ ESC, 't', 21 };
};

pub const upside_down_mode = struct {
    pub const disable = [_]u8{ ESC, '{', 0 };
    pub const enable = [_]u8{ ESC, '{', 1 };
};

pub fn printNvBitimage(image: u8, mode: nv_bit_image_mode) [4]u8 {
    return [_]u8{ FS, 'p', image, @enumToInt(mode) };
}

pub const nv_bit_image_mode = enum(u2) {
    normal,
    double_width,
    double_height,
    quadruple
};

// Define NV bit image is not implemented yet

pub fn selectCharacterSize(height: u3, width: u3) [3]u8 {
    var n: u8 = 0;
    n |= height;
    n |= (@as(u8, width) << 4);
    return [_]u8{ GS, '!', n };
}

/// • Sets the absolute vertical print starting position for buffer
///   character data in page mode.
/// • This command sets the absolute print position to [( nL + nH ×
///   256) × (vertical or horizontal motion unit)] inches.
pub fn setPageModeAbsoluteVerticalPrintPosition(nl: u8, nh: u8) [4]u8 {
    return [_]u8{ GS, '$', nl, nh };
}

// define downloaded image not implemented yet
// /// Defines a downloaded bit image with the number of dots specified by x and y.
// /// ·x indicates the number of dots in the horizontal direction.
// /// ·y indicates he number of dots in the vertical direction.
// /// Caller is responsible for freeing memory
// pub fn defineDownloadedBitImage(allocator: mem.Allocator, width: u8, height: u6, dots: []const u8) ![]u8 {
//     if (height > 48) {
//         return error.HeightTooLarge;
//     }
//
// }

pub const print_downloaded_bit_image = struct {
    pub const normal = [_]u8{ GS, '/', 0 };
    pub const double_width = [_]u8{ GS, '/', 1 };
    pub const double_height = [_]u8{ GS, '/', 2 };
    pub const quadruple = [_]u8{ GS, '/', 3 };
};

/// Starts or ends macro definition.
/// • Macro definition starts when this command is received during normal operation.
///   Macro definition ends when this command is received during macro definition.
/// • When GS ^ is received during macro definition, the printer ends
///   macro definition and clears the definition.
/// • Macro is not defined when the power is turned on.
/// • The defined contents of the macro are not cleared by ESC @.
///   Therefore, ESC @ can be included in the contents of the macro
///   definition.
/// • If the printer receives GS : again immediately after previously
///   receiving GS : the printer remains in the macro undefined state.
/// • The contents of the macro can be defined up to 2048 bytes. If
///   the macro definition exceed 2048 bytes, excess data is not stored.
pub const start_or_end_macro_definition = [_]u8{ GS, ':' };

/// Turns on or off white/black reverse printing mode.
pub const reverse_white_black_mode = struct {
    pub const off = [_]u8{ GS, 'B', 0 };
    pub const on = [_]u8{ GS, 'B', 1 };
};

/// Selects the printing position of HRI characters when printing a
/// bar code.
/// • HRI indicates Human Readable Interpretation.
pub const select_hri_characters_printing_position = struct {
    pub const not_printed = [_]u8{ GS, 'H', 0 };
    pub const above_bar_code = [_]u8{ GS, 'H', 1 };
    pub const below_bar_code = [_]u8{ GS, 'H', 2 };
    pub const above_and_below_bar_code = [_]u8{ GS, 'H', 3 };
};

/// Sets the left margin using nL and nH.
/// The left margin is set to [(nL + nH X 256) X (horizontal motion unit)] inches.
pub fn setLeftMargin(nl: u8, nh: u8) [4]u8 {
    [_]u8{ GS, 'L', nl, nh };
}

/// Sets the horizontal and vertical motion units to approximately
/// 25.4/ x mm { 1/ x inches} and approximately 25.4/ y mm {1/ y
/// inches}, respectively. When x and y are set to 0, the default
/// setting of each value is used.
/// [Default] x = 180, y = 360
pub fn setMotionUnits(x: u8, y: u8) [4]u8 {
    return [_]u8{ GS, 'P', x, y };
}

pub const partial_cut = [_]u8{ GS, 'V', 1 };

/// Feeds paper (cutting position + [n x(vertical motion unit)]), and cuts the paper partially
pub fn feedAndPartualCut(units: u8) [4]u8 {
    return [_]u8{ GS, 'V', 66, units };
}

pub const cut = "\n\n\n\n" ++ "\x1DV\x01";
