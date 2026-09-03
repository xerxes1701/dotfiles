//! Fixture for verify.sh. Exercises the Rust path: rust-analyzer attach,
//! treesitter parse, inlay hints, code lens.

fn main() {
    let msg = greet("world");
    println!("{msg}");
}

fn greet(who: &str) -> String {
    format!("hello, {who}")
}

#[cfg(test)]
mod tests {
    use super::greet;

    #[test]
    fn greets() {
        assert_eq!(greet("you"), "hello, you");
    }
}
