defmodule Iconvex.Telecom.Codecs do
  @moduledoc false

  @languages [
    {:turkish, 1, "TURKISH"},
    {:spanish, 2, "SPANISH"},
    {:portuguese, 3, "PORTUGUESE"},
    {:bengali, 4, "BENGALI"},
    {:gujarati, 5, "GUJARATI"},
    {:hindi, 6, "HINDI"},
    {:kannada, 7, "KANNADA"},
    {:malayalam, 8, "MALAYALAM"},
    {:oriya, 9, "ORIYA"},
    {:punjabi, 10, "PUNJABI"},
    {:tamil, 11, "TAMIL"},
    {:telugu, 12, "TELUGU"},
    {:urdu, 13, "URDU"}
  ]

  @base %{
    module: Iconvex.Telecom.Codecs.GSM0338,
    canonical: "GSM0338",
    aliases: ["GSM-03.38", "GSM-03.38-2009", "GSM7", "GSM-7", "SMPP-GSM7"],
    locking: 0,
    single_shift: 0
  }

  @profiles Enum.map(@languages, fn {_name, id, label} ->
              locking = if id == 2, do: 0, else: id

              %{
                module:
                  Module.concat(__MODULE__, "GSM0338#{Macro.camelize(String.downcase(label))}"),
                canonical: "GSM0338-#{label}",
                aliases: ["GSM-03.38-#{label}"],
                locking: locking,
                single_shift: id
              }
            end)

  @locking_only @languages
                |> Enum.reject(fn {_name, id, _label} -> id == 2 end)
                |> Enum.map(fn {_name, id, label} ->
                  %{
                    module:
                      Module.concat(
                        __MODULE__,
                        "GSM0338Locking#{Macro.camelize(String.downcase(label))}"
                      ),
                    canonical: "GSM0338-LOCKING-#{label}",
                    aliases: ["GSM-03.38-LOCKING-#{label}"],
                    locking: id,
                    single_shift: 0
                  }
                end)

  @single_only Enum.map(@languages, fn {_name, id, label} ->
                 %{
                   module:
                     Module.concat(
                       __MODULE__,
                       "GSM0338Single#{Macro.camelize(String.downcase(label))}"
                     ),
                   canonical: "GSM0338-SINGLE-#{label}",
                   aliases: ["GSM-03.38-SINGLE-#{label}"],
                   locking: 0,
                   single_shift: id
                 }
               end)

  @specs [@base | @profiles ++ @locking_only ++ @single_only]

  def modules,
    do:
      Enum.map(@specs, & &1.module) ++
        [
          Iconvex.Telecom.ITA1,
          Iconvex.Telecom.ITA2,
          Iconvex.Telecom.ITA2S2,
          Iconvex.Telecom.ITA2USTTY,
          Iconvex.Telecom.MTK2,
          Iconvex.Telecom.ITA3,
          Iconvex.Telecom.ITA4,
          Iconvex.Telecom.IA5,
          Iconvex.Telecom.Morse,
          Iconvex.Telecom.CCIR476,
          Iconvex.Telecom.AIS6,
          Iconvex.Telecom.IBM2780SixBitTranscode,
          Iconvex.Telecom.IBMBscSixBitTranscode,
          Iconvex.Telecom.TBCDCodec,
          Iconvex.Telecom.SIMAlphaIdentifierCodec
        ]

  def specs, do: @specs

  for spec <- @specs do
    defmodule spec.module do
      use Iconvex.Telecom.Codec,
        canonical: spec.canonical,
        aliases: spec.aliases,
        locking: spec.locking,
        single_shift: spec.single_shift
    end
  end
end
