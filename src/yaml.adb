with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;

with Interfaces.C.Strings;

package body YAML is

   use type C_Int;

   procedure Deallocate is new Ada.Unchecked_Deallocation
     (String, String_Access);

   ----------------------
   -- C symbol imports --
   ----------------------

   procedure C_Document_Delete (Document : in out C_Document_T)
      with Import, Convention => C, External_Name => "yaml_document_delete";

   function C_Document_Get_Root_Node
     (Document : C_Document_Access) return C_Node_Access
      with
         Import,
         Convention    => C,
         External_Name => "yaml_document_get_root_node";

   function C_Document_Get_Node
     (Document : C_Document_Access;
      Index    : C_Int) return C_Node_Access
   with
      Import, Convention => C, External_Name => "yaml_document_get_node";

   function C_Parser_Initialize (Parser : C_Parser_Access) return C_Int
      with Import, Convention => C, External_Name => "yaml_parser_initialize";

   function Allocate_Parser return C_Parser_Access
      with Import, Convention => C, External_Name => "yaml__allocate_parser";

   function C_Parser_Load
     (Parser : C_Parser_Access; Document : C_Document_Access) return C_Int
      with Import, Convention => C, External_Name => "yaml_parser_load";

   procedure C_Parser_Set_Input_String
     (Parser : C_Parser_Access;
      Input  : C_Char_Access;
      Size   : Interfaces.C.size_t)
      with
         Import,
         Convention    => C,
         External_Name => "yaml_parser_set_input_string";

   procedure C_Parser_Set_Input_File
     (Parser : C_Parser_Access;
      File   : C_File_Ptr)
      with Import,
           Convention    => C,
           External_Name => "yaml_parser_set_input_file";

   procedure C_Parser_Delete (Parser : C_Parser_Access)
      with Import, Convention => C, External_Name => "yaml_parser_delete";

   procedure Deallocate_Parser (Parser : C_Parser_Access)
      with Import, Convention => C, External_Name => "yaml__deallocate_parser";

   function C_Fopen
     (Path, Mode : Interfaces.C.Strings.chars_ptr) return C_File_Ptr
      with Import, Convention => C, External_Name => "fopen";

   function C_Fclose (Stream : C_File_Ptr) return C_Int
      with Import, Convention => C, External_Name => "fclose";

   -------------
   -- Helpers --
   -------------

   function Convert (S : String_Access) return C_Char_Access;

   function Get_Node
     (Document : Document_Type'Class; Index : C_Int) return Node_Ref;
   --  Wrapper around C_Document_Get_Node. Raise a Constraint_Error if Index is
   --  out of range.

   function Wrap
     (Document : Document_Type'Class; N : C_Node_Access) return Node_Ref
   is
     ((Node => N, Document => Document'Unrestricted_Access));

   function Convert (S : String_Access) return C_Char_Access is
      Char_Array : C_Char_Array with Address => S.all'Address;
   begin
      return Char_Array'Unrestricted_Access;
   end Convert;

   function Get_Node
     (Document : Document_Type'Class; Index : C_Int) return Node_Ref
   is
      N : constant C_Node_Access :=
         C_Document_Get_Node (Document.C_Doc'Unrestricted_Access, Index);
   begin
      if N = null then
         raise Constraint_Error;
      end if;
      return Wrap (Document, N);
   end Get_Node;

   ----------
   -- Misc --
   ----------

   overriding procedure Initialize (Document : in out Document_Type) is
   begin
      Document.To_Delete := False;
   end Initialize;

   overriding procedure Finalize (Document : in out Document_Type) is
   begin
      if Document.To_Delete then
         C_Document_Delete (Document.C_Doc);
         Document.To_Delete := False;
      end if;
   end Finalize;

   overriding procedure Initialize (Parser : in out Parser_Type) is
   begin
      Parser.C_Parser := Allocate_Parser;
      if C_Parser_Initialize (Parser.C_Parser) /= 1 then
         --  TODO: determine a good error handling scheme
         raise Program_Error;
      end if;

      Parser.Input_Encoding := Any_Encoding;
      Parser.Input_String := null;
      Parser.Input_File := No_File_Ptr;
   end Initialize;

   overriding procedure Finalize (Parser : in out Parser_Type) is
   begin
      C_Parser_Delete (Parser.C_Parser);
      Deallocate_Parser (Parser.C_Parser);
      Deallocate (Parser.Input_String);
      if Parser.Input_File /= No_File_Ptr
         and then C_Fclose (Parser.Input_File) /= 0
      then
         raise File_Error;
      end if;
   end Finalize;

   -----------------------
   --  Public interface --
   -----------------------

   function Root_Node (Document : Document_Type'Class) return Node_Ref is
   begin
      return Wrap
        (Document,
         C_Document_Get_Root_Node (Document.C_Doc'Unrestricted_Access));
   end Root_Node;

   function Kind (Node : Node_Ref) return Node_Kind is
   begin
      return Node.Node.Kind;
   end Kind;

   function Value (Node : Node_Ref) return UTF8_String is
      Data   : C_Node_Data renames Node.Node.Data;
      Result : UTF8_String (1 .. Natural (Data.Scalar.Length))
         with Address => Data.Scalar.Value.all'Address;
   begin
      return Result;
   end Value;

   function Length (Node : Node_Ref) return Natural is
      use C_Node_Item_Accesses, C_Node_Pair_Accesses;
      Data : C_Node_Data renames Node.Node.Data;
   begin
      return
        (case Kind (Node) is
         when Sequence_Node => Natural
           (Data.Sequence.Items.Seq_Top - Data.Sequence.Items.Seq_Start),
         when Mapping_Node  => Natural
           (Data.Mapping.Pairs.Map_Top - Data.Mapping.Pairs.Map_Start),
         when others => raise Program_Error);
   end Length;

   function Item (Node : Node_Ref; Index : Positive) return Node_Ref
   is
      use C_Node_Item_Accesses;
      Data : C_Node_Data renames Node.Node.Data;
      Item : constant C_Node_Item_Access :=
         Data.Sequence.Items.Seq_Start + C_Ptr_Diff (Index - 1);
   begin
      return Get_Node (Node.Document.all, Item.all);
   end Item;

   function Item (Node : Node_Ref; Index : Positive) return Node_Pair
   is
      use C_Node_Pair_Accesses;
      Data : C_Node_Data renames Node.Node.Data;
      Pair : constant C_Node_Pair_Access :=
         Data.Mapping.Pairs.Map_Start + C_Ptr_Diff (Index - 1);
   begin
      return (Key   => Get_Node (Node.Document.all, Pair.Key),
              Value => Get_Node (Node.Document.all, Pair.Value));
   end Item;

   function Item (Node : Node_Ref; Key : UTF8_String) return Node_Ref
   is
   begin
      for I in 1 .. Length (Node) loop
         declare
            Pair : constant Node_Pair := Item (Node, I);
         begin
            if Kind (Pair.Key) = Scalar_Node
               and then Value (Pair.Key) = Key
            then
               return Pair.Value;
            end if;
         end;
      end loop;
      return No_Node_Ref;
   end Item;

   procedure Set_Input_String
     (Parser   : in out Parser_Type'Class;
      Input    : String;
      Encoding : Encoding_Type)
   is
   begin
      Parser.Input_Encoding := Encoding;
      Deallocate (Parser.Input_String);
      Parser.Input_String := new String'(Input);
      C_Parser_Set_Input_String
        (Parser.C_Parser,
         Convert (Parser.Input_String),
         Parser.Input_String'Length);
   end Set_Input_String;

   procedure Set_Input_File
     (Parser   : in out Parser_Type'Class;
      Filename : String;
      Encoding : Encoding_Type)
   is
      use Interfaces.C.Strings;

      C_Mode     : chars_ptr := New_String ("r");
      C_Filename : chars_ptr := New_String (Filename);
      File       : constant C_File_Ptr := C_Fopen (C_Filename, C_Mode);
   begin
      Free (C_Mode);
      Free (C_Filename);

      if File = No_File_Ptr then
         raise File_Error;
      end if;

      Deallocate (Parser.Input_String);
      Parser.Input_Encoding := Encoding;
      Parser.Input_File := File;
      C_Parser_Set_Input_File (Parser.C_Parser, Parser.Input_File);
   end Set_Input_File;

   function Load (Parser : in out Parser_Type'Class) return Document_Type is
   begin
      return Document : Document_Type do
         if C_Parser_Load
           (Parser.C_Parser, Document.C_Doc'Unrestricted_Access) /= 1
         then
            --  TODO: determine a good error handling scheme
            raise Program_Error;
         end if;
         Document.To_Delete := True;
      end return;
   end Load;

end YAML;
