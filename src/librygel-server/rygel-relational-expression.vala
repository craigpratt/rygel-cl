/*
 * Copyright (C) 2009 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *         Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using GUPnP;

/**
 * This is a parsed UPnP search expression consisting of two strings joined by a
 * relational operator such as such <, <=, ==, !=, >, >=, derivedFrom or exists.
 */
public class Rygel.RelationalExpression :
             Rygel.SearchExpression<SearchCriteriaOp,string,string> {
    public override bool satisfied_by (MediaObject media_object) {
        return media_object.satisfies (this);
    }

    public override string to_string () {
        return "%s %d %s".printf (this.operand1, this.op, this.operand2);
    }

    public bool compare_string (string? str) {
        var up_operand2 = this.operand2.up ();
        string up_str;
        if (str != null) {
            up_str = str.up ();
        } else {
            up_str = null;
        }

        switch (this.op) {
        case SearchCriteriaOp.EXISTS:
            if (this.operand2 == "true") {
                return up_str != null;
            } else {
                return up_str == null;
            }
        case SearchCriteriaOp.EQ:
            return up_operand2 == up_str;
        case SearchCriteriaOp.NEQ:
            return up_operand2 != up_str;
        case SearchCriteriaOp.CONTAINS:
            return up_str.contains (up_operand2);
        case SearchCriteriaOp.DERIVED_FROM:
            return up_str.has_prefix (up_operand2);
        default:
            return false;
        }
    }

    public bool compare_int (int integer) {
        var operand2 = int.parse (this.operand2);

        switch (this.op) {
        case SearchCriteriaOp.EQ:
            return integer == operand2;
        case SearchCriteriaOp.NEQ:
            return integer != operand2;
        case SearchCriteriaOp.LESS:
            return integer < operand2;
        case SearchCriteriaOp.LEQ:
            return integer <= operand2;
        case SearchCriteriaOp.GREATER:
            return integer > operand2;
        case SearchCriteriaOp.GEQ:
            return integer >= operand2;
        default:
            return false;
        }
    }

    public bool compare_uint (uint integer) {
        var operand2 = uint64.parse (this.operand2);

        switch (this.op) {
        case SearchCriteriaOp.EQ:
            return integer == operand2;
        case SearchCriteriaOp.NEQ:
            return integer != operand2;
        case SearchCriteriaOp.LESS:
            return integer < operand2;
        case SearchCriteriaOp.LEQ:
            return integer <= operand2;
        case SearchCriteriaOp.GREATER:
            return integer > operand2;
        case SearchCriteriaOp.GEQ:
            return integer >= operand2;
        default:
            return false;
        }
    }
}
