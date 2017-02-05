private with Ada.Finalization;

private with Interfaces;
private with Interfaces.C;

private with System;

package YAML is

   type Document_Type is tagged limited private;
   --  Holder for a YAML document

   type Node_Kind is
     (No_Node,
      --  An empty node

      Scalar_Node,
      --  A scalar node

      Sequence_Node,
      --  A sequence node

      Mapping_Node
      --  A mapping node
     ) with
      Convention => C;
   --  Type of a node in a document

   type Node_Ref is private;
   --  Reference to a node as part of a document

   No_Node_Ref : constant Node_Ref;

   function Root_Node (Document : Document_Type'Class) return Node_Ref;
   --  Return the root node of a document, or No_Node_Ref for an empty
   --  document.

   function Kind (Node : Node_Ref) return Node_Kind;
   --  Return the type of a node

   type Parser_Type is tagged limited private;
   --  YAML document parser

   type Encoding_Type is
     (Any_Encoding,
      --  Let the parser choose the encoding

      UTF8_Encoding,
      --  The default UTF-8 encoding

      UTF16LE_Encoding,
      --  The UTF-16-LE encoding with BOM

      UTF16BE_Encoding
      --  The UTF-16-BE encoding with BOM
     ) with
      Convention => C;
   --  Stream encoding

   procedure Set_Input_String
     (Parser   : in out Parser_Type'Class;
      Input    : String;
      Encoding : Encoding_Type);
   --  Set a string input. This maintains a copy of Input in Parser.

   function Load (Parser : in out Parser_Type'Class) return Document_Type;
   --  Parse the input stream and produce the next YAML document.
   --
   --  Call this function subsequently to produce a sequence of documents
   --  constituting the input stream. If the produced document has no root
   --  node, it means that the document end has been reached.
   --
   --  TODO: error handling

private

   subtype C_Int is Interfaces.C.int;

   type C_Char_Array is
      array (C_Int range 0 .. C_Int'Last) of Interfaces.Unsigned_8;
   type C_Char_Access is access C_Char_Array;

   type C_Node_T;
   type C_Node_Access is access all C_Node_T;

   type C_Scalar_Style_T is
     (Any_Scalar_Style,
      Plain_Scalar_Style,
      Single_Quoted_Scalar_Style,
      Double_Quoted_Scalar_Style,
      Literal_Scalar_Style,
      Folded_Scalar_Style) with
      Convention => C;
   --  Scalar styles

   type C_Sequence_Style_T is
     (Any_Sequence_Style,
      Block_Sequence_Style,
      Flow_Sequence_Style) with
      Convention => C;
   --  Sequence styles

   type C_Mapping_Style_T is
     (Any_Mapping_Style,
      Block_Mapping_Style,
      Flow_Mapping_Style) with
      Convention => C;
   --  Mapping styles

   type C_Mark_T is record
      Index, Line, Column : Interfaces.C.size_t;
   end record with
      Convention => C_Pass_By_Copy;
   --  The pointer position

   type C_Version_Directive_T is record
      Major, Minor : C_Int;
      --  Major and minor version numbers
   end record with
      Convention => C_Pass_By_Copy;
   --  The version directive data

   type C_Version_Directive_Access is access all C_Version_Directive_T;

   type C_Tag_Directive_T is record
      Handle : C_Char_Access;
      --  The tag handle

      Prefix : C_Char_Access;
      --  The tag prefix
   end record with
      Convention => C_Pass_By_Copy;
   --  The tag directive data

   type C_Tag_Directive_Access is access C_Tag_Directive_T;

   subtype C_Node_Item_T is C_Int;
   type C_Node_Item_Access is access all C_Node_Item_T;

   type C_Node_Pair_T is record
      Key, Value : C_Int;
   end record with
      Convention => C_Pass_By_Copy;
   type C_Node_Pair_Access is access all C_Node_Pair_T;

   ----------------------------
   -- Node structure binding --
   ----------------------------

   type C_Scalar_Node_Data is record
      Value  : C_Char_Access;
      --  The scalar value

      Length : Interfaces.C.size_t;
      --  The length of the scalar value

      Style  : C_Scalar_Style_T;
      --  The scalar style
   end record with
      Convention => C_Pass_By_Copy;

   type C_Sequence_Items is record
      Seq_Start, Seq_End, Seq_Top : C_Node_Item_Access;
   end record with
      Convention => C_Pass_By_Copy;

   type C_Sequence_Node_Data is record
      Items : C_Sequence_Items;
      --  The stack of sequence items

      Style : C_Sequence_Style_T;
      --  The sequence style
   end record with
      Convention => C_Pass_By_Copy;

   type C_Mapping_Pairs is record
      Map_Start, Map_End, Map_Top : C_Node_Pair_Access;
   end record with
      Convention => C_Pass_By_Copy;

   type C_Mapping_Node_Data is record
      Pairs : C_Mapping_Pairs;
      --  The stack of mapping pairs

      Style : C_Mapping_Style_T;
      --  The mapping style
   end record with
      Convention => C_Pass_By_Copy;

   type C_Node_Data (Dummy : Node_Kind := No_Node) is record
      case Dummy is
         when No_Node =>
            null;

         when Scalar_Node =>
            Scalar : C_Scalar_Node_Data;
            --  The scalar parameters (for Scalar_Node)

         when Sequence_Node =>
            Sequence : C_Sequence_Node_Data;
            --  The sequence parameters (for Sequence_Node)

         when Mapping_Node =>
            Mapping : C_Mapping_Node_Data;
            --  The mapping parameters (for Mapping_Node)
      end case;
   end record with
      Convention => C_Pass_By_Copy,
      Unchecked_Union;

   type C_Node_T is record
      Kind : Node_Kind;
      --  The node type

      Tag  : C_Char_Access;
      --  The node tag

      Data : C_Node_Data;
      --  The node data

      Start_Mark, End_Mark : C_Mark_T;
   end record with
      Convention => C_Pass_By_Copy;

   --------------------------------
   -- Document structure binding --
   --------------------------------

   type C_Document_Nodes is record
      Start_Node, End_Node, Top_Node : C_Node_T;
      --  Begining, end and top of the stack
   end record with
      Convention => C_Pass_By_Copy;

   type C_Tag_Directives is record
      Start_Dir, End_Dir : C_Tag_Directive_Access;
      --  Beginning and end of the tag directives list
   end record with
      Convention => C_Pass_By_Copy;

   type C_Document_T is record
      Nodes                        : C_Document_Nodes;
      --  The document nodes

      Version_Directives           : C_Version_Directive_Access;
      --  The version directive

      Tag_Directives               : C_Tag_Directives;
      --  The list of tag directives

      Start_Implicit, End_Implicit : C_Int;
      --  Is the document start/end indicator explicit?

      Start_Mark, End_Mark         : C_Mark_T;
      --  Beginning and end of the document
   end record with
      Convention => C_Pass_By_Copy;
   --  The document structure

   type C_Document_Access is access all C_Document_T;

   -------------------------
   -- High-level Wrappers --
   -------------------------

   type Document_Type is limited new Ada.Finalization.Limited_Controlled
   with record
      C_Doc     : aliased C_Document_T;
      To_Delete : Boolean;
   end record;

   overriding procedure Initialize (Document : in out Document_Type);
   overriding procedure Finalize (Document : in out Document_Type);

   type Document_Access is access all Document_Type'Class;

   type Node_Ref is record
      Node     : C_Node_Access;
      --  The referenced node

      Document : Document_Access;
      --  The document it belongs to
   end record;

   No_Node_Ref : constant Node_Ref := (null, null);

   type C_Parser_Access is new System.Address;
   type String_Access is access String;

   type Parser_Type is limited new Ada.Finalization.Limited_Controlled
   with record
      C_Parser       : C_Parser_Access;
      Input_Encoding : Encoding_Type;
      Input_String   : String_Access;
   end record;

   overriding procedure Initialize (Parser : in out Parser_Type);
   overriding procedure Finalize (Parser : in out Parser_Type);

end YAML;
