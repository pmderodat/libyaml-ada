with Ada.Text_IO; use Ada.Text_IO;

with YAML;

procedure Parser is

   procedure Process (P : in out YAML.Parser_Type);
   procedure Put (N : YAML.Node_Ref; Indent : Natural);

   procedure Process (P : in out YAML.Parser_Type) is
      D : YAML.Document_Type;
   begin
      P.Load (D);
      Put (D.Root_Node, 0);
      P.Discard_Input;
      New_Line;
   end Process;

   procedure Put (N : YAML.Node_Ref; Indent : Natural) is
      Prefix : constant String := (1 .. Indent => ' ');
   begin
      case YAML.Kind (N) is
         when YAML.No_Node =>
            Put_Line (Prefix & "<null>");

         when YAML.Scalar_Node =>
            Put_Line (Prefix & String (N.Value));

         when YAML.Sequence_Node =>
            for I in 1 .. N.Length loop
               Put_Line (Prefix & "- ");
               Put (N.Item (I), Indent + 2);
            end loop;

         when YAML.Mapping_Node =>
            Put_Line ("Pairs:");
            for I in 1 .. N.Length loop
               declare
                  Pair : constant YAML.Node_Pair := N.Item (I);
               begin
                  Put (Prefix & "Key:");
                  Put (Pair.Key, Indent + 2);
                  Put (Prefix & "Value:");
                  Put (Pair.Value, Indent + 2);
               end;
            end loop;
      end case;
   end Put;

   P : YAML.Parser_Type;

begin
   P.Set_Input_String ("1", YAML.UTF8_Encoding);
   Process (P);

   P.Set_Input_String ("[1, 2, 3, a, null]", YAML.UTF8_Encoding);
   Process (P);

   P.Set_Input_String ("foo: 1", YAML.UTF8_Encoding);
   Process (P);

   P.Set_Input_File ("parser-valid.yaml", YAML.UTF8_Encoding);
   Process (P);
end Parser;
