import customtkinter as ctk

app = ctk.CTk()
app.title("Zenith - teste de janela")
app.geometry("400x200")
ctk.CTkLabel(app, text="CustomTkinter funcionando", font=("Arial", 18)).pack(pady=40)
ctk.CTkButton(app, text="Fechar", command=app.destroy).pack()
app.mainloop()
