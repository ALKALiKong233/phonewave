//! Carrier modem configuration selection (PDC) over QMI.

use std::time::Duration;

use async_io::Timer;
use futures_lite::future;

use crate::qmi::{Client, Error, Message};

const SET_SELECTED_CONFIG: u16 = 0x0023;
const ACTIVATE_CONFIG: u16 = 0x0027;
const CONFIG_TYPE_SOFTWARE: u32 = 1;
const NO_EFFECT: u16 = 0x001a;
const TIMEOUT: Duration = Duration::from_secs(10);

async fn wait_indication(pdc: &Client, id: u16, token: u32) -> Result<(), Error> {
    let deadline = async {
        Timer::after(TIMEOUT).await;
        Err(Error::Timeout)
    };
    let wait = async {
        loop {
            let msg = pdc.indication().await?;
            if msg.id != id {
                continue;
            }
            if let Some(v) = msg.tlv(0x10)
                && v.len() == 4
                && u32::from_le_bytes(v.try_into().unwrap()) != token
            {
                continue;
            }
            return match msg.tlv(0x01) {
                Some(&[0, 0]) | None => Ok(()),
                Some(&[e0, e1]) => Err(Error::Qmi(u16::from_le_bytes([e0, e1]))),
                _ => Err(Error::Malformed("invalid PDC indication")),
            };
        }
    };
    future::or(wait, deadline).await
}

/// Selects and activates the software MBN `id` (already present in modem PDC).
/// Returns `Ok(true)` if activation was triggered, `Ok(false)` if already active.
pub async fn activate_software(pdc: &Client, id: &[u8; 20]) -> Result<bool, Error> {
    let token: u32 = 1;
    let mut val01 = Vec::with_capacity(25);
    val01.extend_from_slice(&CONFIG_TYPE_SOFTWARE.to_le_bytes());
    val01.push(id.len() as u8);
    val01.extend_from_slice(id);

    let sel = Message::request(SET_SELECTED_CONFIG)
        .with(0x01, val01)
        .with(0x10, token.to_le_bytes());
    pdc.call(sel, TIMEOUT).await?;
    wait_indication(pdc, SET_SELECTED_CONFIG, token).await?;

    let act = Message::request(ACTIVATE_CONFIG)
        .with(0x01, CONFIG_TYPE_SOFTWARE.to_le_bytes())
        .with(0x10, (token + 1).to_le_bytes());
    match pdc.call(act, TIMEOUT).await {
        Ok(_) => {
            wait_indication(pdc, ACTIVATE_CONFIG, token + 1).await?;
            Ok(true)
        }
        Err(Error::Qmi(NO_EFFECT)) => Ok(false),
        Err(e) => Err(e),
    }
}
