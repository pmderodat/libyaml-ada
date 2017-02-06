with Ada.Text_IO; use Ada.Text_IO;

with YAML;

procedure Example is

   procedure Process (S : String);
   procedure Put (N : YAML.Node_Ref; Indent : Natural);

   procedure Process (S : String) is
      P : YAML.Parser_Type;
   begin
      P.Set_Input_String (S, YAML.UTF8_Encoding);
      declare
         D : constant YAML.Document_Type := P.Load;
         N : constant YAML.Node_Ref := D.Root_Node;
      begin
         Put (N, 0);
      end;
      New_Line;
   end Process;

   procedure Put (N : YAML.Node_Ref; Indent : Natural) is
      Prefix : constant String := (1 .. Indent => ' ');
   begin
      case YAML.Kind (N) is
         when YAML.No_Node =>
            Put_Line (Prefix & "<null>");

         when YAML.Scalar_Node =>
            Put_Line (Prefix & String (YAML.Scalar_Value (N)));

         when YAML.Sequence_Node =>
            for I in 1 .. YAML.Sequence_Length (N) loop
               Put_Line (Prefix & "- ");
               Put (YAML.Sequence_Item (N, I), Indent + 2);
            end loop;

         when YAML.Mapping_Node =>
            Put_Line ("Pairs:");
            for I in 1 .. YAML.Mapping_Length (N) loop
               declare
                  Pair : constant YAML.Node_Pair := YAML.Mapping_Item (N, I);
               begin
                  Put (Prefix & "Key:");
                  Put (Pair.Key, Indent + 2);
                  Put (Prefix & "Value:");
                  Put (Pair.Value, Indent + 2);
               end;
            end loop;
      end case;
   end Put;

begin
   Process ("1");
   Process ("[1, 2, 3, a, null]");
   Process ("foo: 1");
end Example;
